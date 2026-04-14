import 'dotenv/config';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import {
    initDb,
    createHighscore,
    getHighscores,
    getSpamMails,
    getAllMailSubjects,
    insertGeneratedSpamMails,
    truncateMails,
    truncateHighscores,
    getAllMails
} from './db.js';
import { generateSpamMailsWithAI } from './spamGenerator.js';

const app = express();
const PORT = Number(process.env.PORT || 3000);
const API_KEY = process.env.API_KEY;
const MAX_MAILS_PER_REQUEST = 20;

app.use(helmet());
app.use(cors({
    origin: (origin, cb) => cb(null, true),
    credentials: false
}));
app.use(express.json({
    limit: '32kb'
}));

const globalLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 120,
    standardHeaders: true,
    legacyHeaders: false,
    message: 'Too many requests, slow down.'
});

app.use(globalLimiter);

function requireKey(req, res, next) {
    if (!API_KEY) return res.status(500).json({
        error: 'Server API key not configured.'
    });
    const key = req.get('x-api-key');
    if (key !== API_KEY) return res.status(401).json({
        error: 'Unauthorized'
    });
    next();
}

function normalizeReceivedMailIds(rawIds) {
    if (rawIds === undefined) return [];
    if (!Array.isArray(rawIds)) return null;

    const parsed = rawIds.map((id) => Number(id));
    if (parsed.some((id) => !Number.isInteger(id) || id <= 0)) return null;

    return Array.from(new Set(parsed));
}

function getDifficultyForUser(receivedCount) {
    if (receivedCount < 5) return 'easy';
    if (receivedCount < 15) return 'medium';
    return 'hard';
}

await initDb();

// --- Routes ---
app.get('/health', async (_req, res) => {
    res.json({
        ok: true,
        uptime: process.uptime(),
        time: new Date().toISOString()
    });
});

app.post('/spam-mails/batch', requireKey, async (req, res) => {
    try {
        const {
            count = 5,
            receivedMailIds
        } = req.body || {};

        const requestedCount = Number(count);
        if (!Number.isInteger(requestedCount) || requestedCount < 1 || requestedCount > MAX_MAILS_PER_REQUEST) {
            return res.status(400).json({
                error: `count must be an integer between 1 and ${MAX_MAILS_PER_REQUEST}`
            });
        }

        const parsedReceivedMailIds = normalizeReceivedMailIds(receivedMailIds);
        if (parsedReceivedMailIds === null) {
            return res.status(400).json({
                error: 'receivedMailIds must be an array of positive integer ids'
            });
        }

        let mails = await getSpamMails({
            count: requestedCount,
            excludeIds: parsedReceivedMailIds
        });

        let generatedCount = 0;
        if (mails.length < requestedCount) {
            if (!process.env.OPENAI_API_KEY) {
                return res.status(503).json({
                    error: 'Mail pool exhausted and OPENAI_API_KEY is not configured.'
                });
            }

            const missingCount = requestedCount - mails.length;
            const difficulty = getDifficultyForUser(parsedReceivedMailIds.length);
            const existingSubjects = await getAllMailSubjects();
            const generatedMails = await generateSpamMailsWithAI({
                count: missingCount + 3,
                difficulty,
                existingSubjects
            });

            generatedCount = await insertGeneratedSpamMails(generatedMails);

            const refreshedExcludeIds = Array.from(new Set([
                ...parsedReceivedMailIds,
                ...mails.map((mail) => mail.id)
            ]));

            const topUpMails = await getSpamMails({
                count: requestedCount - mails.length,
                excludeIds: refreshedExcludeIds
            });

            mails = mails.concat(topUpMails);
        }

        res.json({
            mails,
            requestedCount,
            returnedCount: mails.length,
            generatedCount
        });
    } catch (err) {
        console.error('Get spam mails error:', err);
        res.status(500).json({
            error: 'Server error'
        });
    }
});

// Create highscore
app.post('/highscores', requireKey, async (req, res) => {
    try {
        const {
            username,
            highscore
        } = req.body || {};

        console.log("Post to /highscores with username:", username);
        if (typeof username !== 'string') {
            return res.status(400).json({
                error: 'Invalid body'
            });
        }

        const trimmedName = username.trim();

        if (trimmedName.length < 1 || trimmedName.length > 100) {
            return res.status(400).json({
                error: 'Invalid name length'
            });
        }

        const parsedHighscore = Number(highscore);
        if (!Number.isInteger(parsedHighscore) || parsedHighscore < 0) {
            return res.status(400).json({
                error: 'Invalid highscore'
            });
        }

        const createdHighscore = await createHighscore({
            username: trimmedName,
            highscore: parsedHighscore
        });
        res.status(201).json({
            highscore: createdHighscore
        });
    } catch (err) {
        console.error('Create highscore error:', err);
        res.status(500).json({
            error: 'Server error'
        });
    }
});

app.get('/highscores', requireKey, async (req, res) => {
    try {
        const highscores = await getHighscores();
        if (!highscores) return res.status(404).json({
            error: 'Not found'
        });
        res.json({
            highscores
        });
    } catch (err) {
        console.error('Get highscores error:', err);
        res.status(500).json({
            error: 'Server error'
        });
    }
});


app.post('/truncate_highscores', requireKey, async (req, res) => {
    try {
        await truncateHighscores();
        res.json({
            ok: true
        });
    } catch (err) {
        console.error('Truncate highscores error:', err);
        res.status(500).json({
            error: 'Server error'
        });
    }
});

app.post('/truncate_mails', requireKey, async (req, res) => {
    try {
        await truncateMails();
        res.json({
            ok: true
        });
    } catch (err) {
        console.error('Truncate mails error:', err);
        res.status(500).json({
            error: 'Server error'
        });
    }
});

app.get('/all_mails', requireKey, async (req, res) => {
    try {
        const mails = await getAllMails();
        res.json({
            mails
        });
    } catch (err) {
        console.error('Get all mails error:', err);
        res.status(500).json({
            error: 'Server error'
        });
    }
});

app.listen(PORT, () => {
    console.log(`API listening on http://0.0.0.0:${PORT}`);
});