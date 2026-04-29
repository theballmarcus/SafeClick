import OpenAI from 'openai';

const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
const VALID_DIFFICULTIES = new Set(['easy', 'medium', 'hard']);

function normalizeDay(day) {
    const parsed = Number(day);
    if (Number.isNaN(parsed)) return 1;
    const asInt = Math.trunc(parsed);
    return Math.min(10, Math.max(1, asInt));
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

function normalizeGeneratedMail(mail, fallbackDifficulty) {
    const subject = sanitizeText(mail?.subject, 100);
    const body = sanitizeText(mail?.body, 1200);
    if (!subject || !body) return null;

    if (typeof mail?.is_phishing !== 'boolean') return null;

    const difficultyValue = sanitizeText(mail?.difficulty, 10)?.toLowerCase();
    const difficulty = VALID_DIFFICULTIES.has(difficultyValue)
        ? difficultyValue
        : fallbackDifficulty;

    const senderEmail = sanitizeText(mail?.sender_email, 255);
    const senderName = sanitizeText(mail?.sender_name, 255);

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

    const requestedCount = Math.min(count, 30);
    const normalizedDay = normalizeDay(day);
    const difficultyDistribution = getDifficultyDistributionForDay(normalizedDay);
    const fallbackDifficulty = normalizedDay <= 3
        ? 'easy'
        : normalizedDay <= 7
            ? 'medium'
            : 'hard';

    const blockedSubjects = existingSubjects.map((value) => value.trim());

    let completion;
    try {
        completion = await openai.chat.completions.create({
            model: OPENAI_MODEL,
            temperature: 0.7,
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
      "sender_name": "string",
      "sender_email": "string",
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
- Mails must always include a subject and body, but sender_name, sender_email, real_url, hint
- About 55% should be phishing and 45% should be real. Include BOTH types using is_phishing true/false.
- Target difficulty distribution for this day:
    - easy: ${difficultyDistribution.easy}
    - medium: ${difficultyDistribution.medium}
    - hard: ${difficultyDistribution.hard}
- You can use real company names.
- If you send a link in bodytext, as an example, you can write [l]click me[/l], and put the real URL in real_url field.
- ALL text must be in natural Danish (subjects, body, sender names where appropriate, hints, categories).
- Optionally, you can address the recipient by different common Danish names in the body to add realism.
- Avoid using subjects from this existing subject list:
${JSON.stringify(blockedSubjects)}
- Vary writing styles and tactics like urgency, curiosity, fear, or impersonation to create a diverse set of emails.
- Difficult mails should be hard to distinguish from real mails, while easy ones should have more obvious red flags.
- Maximum 1000 characters in each body, but vary between short and long mails.
- For real mails, hint can explain why it looks legitimate, and for phishing mails it can point out red flags without giving away the exact attack vector.
`
                }
            ]
        });
    } catch (error) {
        const status = error?.status || 'unknown';
        const details = error?.message || String(error);
        throw new Error(`OpenAI API request failed (${status}): ${details}`);
    }

    const content = completion?.choices?.[0]?.message?.content;
    const parsed = parseJsonPayload(content);

    const normalized = [];

    for (const candidate of parsed.mails) {
        const mail = normalizeGeneratedMail(candidate, fallbackDifficulty);
        if (!mail) continue;

        normalized.push(mail);
    }

    return normalized;
}
