import OpenAI from 'openai';

const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
const VALID_DIFFICULTIES = new Set(['easy', 'medium', 'hard']);

function normalizeDay(day) {
    const parsed = Number(day);
    if (!Number.isInteger(parsed)) return 1;
    return Math.min(10, Math.max(1, parsed));
}

function getDifficultyDistributionForDay(day) {
    const normalizedDay = normalizeDay(day);
    const progress = (normalizedDay - 1) / 9;

    const easy = 0.85 - (0.65 * progress);
    const hard = 0.05 + (0.65 * progress);
    const medium = Math.max(0, 1 - easy - hard);

    return {
        easy: Number(easy.toFixed(2)),
        medium: Number(medium.toFixed(2)),
        hard: Number(hard.toFixed(2))
    };
}

function stripCodeFences(text) {
    const trimmed = String(text || '').trim();
    if (!trimmed.startsWith('```')) return trimmed;

    const lines = trimmed.split('\n');
    if (lines.length < 3) return trimmed;
    if (lines[0].startsWith('```')) lines.shift();
    if (lines[lines.length - 1].startsWith('```')) lines.pop();
    return lines.join('\n').trim();
}

function parseJsonPayload(text) {
    const cleaned = stripCodeFences(text);
    try {
        return JSON.parse(cleaned);
    } catch {
        const start = cleaned.indexOf('{');
        const end = cleaned.lastIndexOf('}');
        if (start === -1 || end === -1 || end <= start) return null;
        try {
            return JSON.parse(cleaned.slice(start, end + 1));
        } catch {
            return null;
        }
    }
}

function sanitizeText(value, maxLength) {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    return trimmed.slice(0, maxLength);
}

function titleCaseWords(value) {
    return String(value)
        .split(' ')
        .filter(Boolean)
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
        .join(' ')
        .trim();
}

function inferSenderNameFromEmail(senderEmail) {
    if (!senderEmail) return null;

    const localPart = String(senderEmail).split('@')[0] || '';
    const cleaned = localPart
        .replace(/[._-]+/g, ' ')
        .replace(/[^a-zA-Z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

    if (!cleaned) return null;
    return titleCaseWords(cleaned).slice(0, 255) || null;
}

function resolveSenderName(mail) {
    const directSenderName = sanitizeText(mail?.sender_name, 255);
    if (directSenderName) return directSenderName;

    const senderEmail = sanitizeText(mail?.sender_email, 255);
    const inferredFromEmail = inferSenderNameFromEmail(senderEmail);
    if (inferredFromEmail) return inferredFromEmail;

    return 'Ukendt afsender';
}

function normalizeGeneratedMail(mail, fallbackDifficulty) {
    const subject = sanitizeText(mail?.subject, 100);
    const body = sanitizeText(mail?.body, 6000);
    if (!subject || !body) return null;

    if (typeof mail?.is_phishing !== 'boolean') return null;

    const difficultyValue = sanitizeText(mail?.difficulty, 10)?.toLowerCase();
    const difficulty = VALID_DIFFICULTIES.has(difficultyValue)
        ? difficultyValue
        : fallbackDifficulty;

    const senderEmail = sanitizeText(mail?.sender_email, 255);
    const senderName = resolveSenderName({
        sender_name: mail?.sender_name,
        sender_email: senderEmail
    });

    return {
        subject,
        sender_name: senderName,
        sender_email: senderEmail,
        body,
        real_url: sanitizeText(mail?.real_url, 255),
        hint: sanitizeText(mail?.hint, 500),
        difficulty,
        category: sanitizeText(mail?.category, 50) || 'generated',
        is_phishing: mail.is_phishing
    };
}

export async function generateSpamMailsWithAI({ count, day = 1, existingSubjects = [] }) {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
        throw new Error('OPENAI_API_KEY is not configured.');
    }

    const openai = new OpenAI({ apiKey });

    const requestedCount = Math.min(Math.max(Number(count) || 1, 1), 30);
    const normalizedDay = normalizeDay(day);
    const difficultyDistribution = getDifficultyDistributionForDay(normalizedDay);
    const fallbackDifficulty = normalizedDay <= 3
        ? 'easy'
        : normalizedDay <= 7
            ? 'medium'
            : 'hard';

    const blockedSubjects = Array.from(new Set(
        (Array.isArray(existingSubjects) ? existingSubjects : [])
            .filter((value) => typeof value === 'string' && value.trim())
            .map((value) => value.trim())
    )).slice(-300);

    let completion;
    try {
        completion = await openai.chat.completions.create({
            model: OPENAI_MODEL,
            temperature: 1.5,
            response_format: { type: 'json_object' },
            messages: [
                {
                    role: 'system',
                    content: 'You generate realistic email training samples in Danish for educational simulation. Always return valid JSON.'
                },
                {
                    role: 'user',
                    content: `Generate ${requestedCount} UNIQUE emails in Danish for day ${normalizedDay}.

Return JSON only in this shape:
{
  "mails": [
    {
      "subject": "string max 100 chars",
    "sender_name": "string (required)",
      "sender_email": "string or null",
      "body": "string",
      "real_url": "string or null",
            "is_phishing": true,
      "hint": "short clue about phishing red flags",
      "difficulty": "easy|medium|hard",
      "category": "one short category"
    }
  ]
}

Rules:
- sender_name must always be present and non-empty.
- Mix phishing and real emails. Include BOTH types using is_phishing true/false.
- About 55% should be phishing and 45% should be real.
- Target difficulty distribution for this day:
    - easy: ${difficultyDistribution.easy}
    - medium: ${difficultyDistribution.medium}
    - hard: ${difficultyDistribution.hard}
- Do not duplicate subjects.
- You can use real company names.
- ALL text must be in natural Danish (subjects, body, sender names where appropriate, hints, categories).
- Do not use any subject from this existing subject list:
${JSON.stringify(blockedSubjects)}
- Vary tactics and writing style.
- Difficult mails should be hard to distinguish from real mails, while easy ones should have more obvious red flags.
- For real mails, hint can explain why it looks legitimate.
- Keep content realistic but safe for training.`
                }
            ]
        });
    } catch (error) {
        const status = error?.status || 'unknown';
        const details = error?.message || String(error);
        throw new Error(`OpenAI API request failed (${status}): ${details.slice(0, 300)}`);
    }

    const content = completion?.choices?.[0]?.message?.content;
    const parsed = parseJsonPayload(content);
    const candidates = Array.isArray(parsed)
        ? parsed
        : Array.isArray(parsed?.mails)
            ? parsed.mails
            : [];

    const blockedSet = new Set(blockedSubjects.map((subject) => subject.toLowerCase()));
    const uniqueSubjects = new Set();
    const normalized = [];

    for (const candidate of candidates) {
        const mail = normalizeGeneratedMail(candidate, fallbackDifficulty);
        if (!mail) continue;

        const key = mail.subject.toLowerCase();
        if (blockedSet.has(key) || uniqueSubjects.has(key)) continue;

        uniqueSubjects.add(key);
        normalized.push(mail);
        if (normalized.length >= requestedCount) break;
    }

    return normalized;
}
