import mysql from 'mysql2/promise';

const pool = mysql.createPool({
    host: process.env.MYSQL_HOST || 'localhost',
    port: process.env.MYSQL_PORT || 3306,
    user: process.env.MYSQL_USER || 'db_user',
    password: process.env.MYSQL_PASSWORD || 'db_pass',
    database: process.env.MYSQL_DATABASE || 'db_db',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

function getDifficultyWeightsForDay(day) {
    const progress = (day - 1) / 9;

    return {
        easy: 5.0 - (4.2 * progress),
        medium: 1.4,
        hard: 0.5 + (4.2 * progress)
    };
}

function toMailRow(mail) {
    const senderEmail = typeof mail.sender_email === 'string' ? mail.sender_email.trim() : '';
    const senderName = typeof mail.sender_name === 'string' ? mail.sender_name.trim() : '';

    return {
        ...mail,
        sender_name: senderName || 'Ukendt afsender',
        is_phishing: Boolean(mail.is_phishing)
    };
}

function pickWeightedRandomMails(rows, count, day) {
    if (!Array.isArray(rows) || rows.length === 0 || count <= 0) return [];

    const poolRows = rows.slice();
    const selected = [];
    const weights = getDifficultyWeightsForDay(day);
    const limit = Math.min(count, poolRows.length);

    for (let i = 0; i < limit; i += 1) {
        const totalWeight = poolRows.reduce((sum, row) => sum + (weights[row.difficulty] ?? 1), 0);
        let pick = Math.random() * totalWeight;
        let chosenIndex = poolRows.length - 1;

        for (let j = 0; j < poolRows.length; j += 1) {
            pick -= weights[poolRows[j].difficulty] ?? 1;
            if (pick <= 0) {
                chosenIndex = j;
                break;
            }
        }

        selected.push(toMailRow(poolRows.splice(chosenIndex, 1)[0]));
    }

    return selected;
}

export async function initDb() {
    const mailsSql = `CREATE TABLE IF NOT EXISTS unique_mails (
    id INT AUTO_INCREMENT PRIMARY KEY,
    subject VARCHAR(100) NOT NULL UNIQUE,
    sender_name VARCHAR(255) DEFAULT NULL,
    sender_email VARCHAR(255) DEFAULT NULL,
    body TEXT NOT NULL,
    real_url VARCHAR(255) DEFAULT NULL,
    is_phishing BOOLEAN NOT NULL,
    hint TEXT DEFAULT NULL,
    difficulty ENUM('easy', 'medium', 'hard') NOT NULL,
    category VARCHAR(50) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB`;
    await pool.query(mailsSql);

    const highscoreSql = `CREATE TABLE IF NOT EXISTS highscore (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(100) NOT NULL,
        highscore INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB`;
    await pool.query(highscoreSql);
}

export async function truncateMails() {
    await pool.query('DROP TABLE unique_mails');
    initDb()
}

export async function truncateHighscores() {
    await pool.query('DROP TABLE highscore');
    initDb();
}

export async function createHighscore({ highscore, username = null }) {
    // Check if a highscore for this username already exists
    const [rows] = await pool.query('SELECT id, highscore FROM highscore WHERE username = ?', [username]);
    if (rows && rows.length > 0) {
        const existing = rows[0];
        const existingScore = Number(existing.highscore) || 0;
        const newScore = Number(highscore) || 0;
        const finalScore = Math.max(existingScore, newScore);

        if (finalScore !== existingScore) {
            await pool.query('UPDATE highscore SET highscore = ?, created_at = CURRENT_TIMESTAMP WHERE id = ?', [finalScore, existing.id]);
        }

        return {
            id: parseInt(existing.id),
            username,
            highscore: finalScore
        };
    }

    const [result] = await pool.query(
        'INSERT INTO highscore (username, highscore) VALUES (?, ?)',
        [username, highscore]
    );

    return {
        id: parseInt(result.insertId),
        username,
        highscore: Number(highscore)
    };
}

export async function getSpamMails({ count = 5, excludeIds = [], day = 1 }) {
    const baseSql = `SELECT id, subject, sender_name, sender_email, body, real_url, is_phishing, hint, difficulty, category, created_at
        FROM unique_mails
        WHERE 1=1`;

    const ordre = ' ORDER BY id DESC';

    let sql = baseSql + ordre;
    let params = [];

    if (excludeIds.length > 0) {
        const placeholders = excludeIds.map(() => '?').join(', ');
        sql = `${baseSql} AND id NOT IN (${placeholders})${ordre}`;
        params = [...excludeIds];
    }

    const [rows] = await pool.query(sql, params);
    return pickWeightedRandomMails(rows, count, day);
}

export async function getAllMailSubjects() {
    const [rows] = await pool.query('SELECT subject FROM unique_mails');
    return rows.map((row) => row.subject).filter(Boolean);
}

export async function insertGeneratedSpamMails(mails) {
    if (!Array.isArray(mails) || mails.length === 0) return 0;

    let insertedCount = 0;
    const sql = `INSERT IGNORE INTO unique_mails
        (subject, sender_name, sender_email, body, real_url, is_phishing, hint, difficulty, category)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`;

    for (const mail of mails) {
        const normalized = toMailRow(mail);
        const [result] = await pool.query(sql, [
            normalized.subject,
            normalized.sender_name,
            normalized.sender_email ?? null,
            normalized.body,
            normalized.real_url ?? null,
            normalized.is_phishing ? 1 : 0,
            normalized.hint ?? null,
            normalized.difficulty,
            normalized.category ?? 'generated'
        ]);
        insertedCount += result.affectedRows || 0;
    }

    return insertedCount;
}

export async function getHighscores() {
    const [rows] = await pool.query(
        'SELECT username, highscore, created_at FROM highscore ORDER BY highscore DESC LIMIT 10');
    if (!rows || rows.length === 0) return null;
    return rows.map((r) => ({
        username: r.username,
        highscore: parseInt(r.highscore),
        created_at: r.created_at
    }));
}

export async function getAllMails() {
    const [rows] = await pool.query('SELECT id, subject, sender_name, sender_email, body, real_url, is_phishing, hint, difficulty, category, created_at FROM unique_mails');
    return rows.map(toMailRow);
}

