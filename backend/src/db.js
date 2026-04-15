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

function normalizeDay(day) {
    const parsed = Number(day);
    if (!Number.isInteger(parsed)) return 1;
    return Math.min(10, Math.max(1, parsed));
}

function getDifficultyWeightsForDay(day) {
    const normalizedDay = normalizeDay(day);
    const progress = (normalizedDay - 1) / 9;

    return {
        easy: 5.0 - (4.2 * progress),
        medium: 1.4,
        hard: 0.5 + (4.2 * progress)
    };
}

function toMailRow(mail) {
    const senderEmail = typeof mail.sender_email === 'string' ? mail.sender_email.trim() : '';
    const senderName = typeof mail.sender_name === 'string' ? mail.sender_name.trim() : '';

    let resolvedSenderName = senderName;
    if (!resolvedSenderName && senderEmail) {
        const localPart = senderEmail.split('@')[0] || '';
        resolvedSenderName = localPart
            .replace(/[._-]+/g, ' ')
            .replace(/[^a-zA-Z0-9\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()                                                                                                                                                                                             
            .split(' ')
            .filter(Boolean)
            .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())              
            .join(' ')
            .trim();
    }

    return {
        ...mail,
        sender_name: resolvedSenderName || 'Ukendt afsender',
        is_phishing: Boolean(mail.is_phishing)
    };
}

function pickWeightedRandomMails(rows, count, day) {
    if (!Array.isArray(rows) || rows.length === 0 || count <= 0) return [];

    const safeCount = Math.min(count, rows.length);
    const weights = getDifficultyWeightsForDay(day);
    const poolRows = rows.slice();
    const selected = [];

    while (selected.length < safeCount && poolRows.length > 0) {
        let totalWeight = 0;
        for (const row of poolRows) {
            totalWeight += weights[row.difficulty] ?? 1;
        }

        if (totalWeight <= 0) {
            const randomIndex = Math.floor(Math.random() * poolRows.length);
            selected.push(toMailRow(poolRows.splice(randomIndex, 1)[0]));
            continue;
        }

        const pick = Math.random() * totalWeight;
        let cumulative = 0;
        let chosenIndex = poolRows.length - 1;

        for (let i = 0; i < poolRows.length; i += 1) {
            cumulative += weights[poolRows[i].difficulty] ?? 1;
            if (pick <= cumulative) {
                chosenIndex = i;
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
}

export async function truncateHighscores() {
    await pool.query('DROP TABLE highscore');
}

export async function createHighscore({ highscore, username = null }) {
    const [result] = await pool.query(
        'INSERT INTO highscore (username, highscore) VALUES (?, ?)',
        [username, highscore]
    );

    return { 
        id: parseInt(result.insertId), 
        username 
    };
}

export async function getSpamMails({ count = 5, excludeIds = [], day = 1 }) {
    const safeCount = Number.isInteger(count) ? count : 5;
    const safeExcludeIds = Array.isArray(excludeIds)
        ? excludeIds.filter((id) => Number.isInteger(id) && id > 0)
        : [];
    const safeDay = normalizeDay(day);

    const baseSql = `SELECT id, subject, sender_name, sender_email, body, real_url, is_phishing, hint, difficulty, category, created_at
        FROM unique_mails
        WHERE 1=1`;

    const orderingSql = ' ORDER BY id DESC';

    let sql = baseSql + orderingSql;
    let params = [];

    if (safeExcludeIds.length > 0) {
        const placeholders = safeExcludeIds.map(() => '?').join(', ');
        sql = `${baseSql} AND id NOT IN (${placeholders})${orderingSql}`;
        params = [...safeExcludeIds];
    }

    const [rows] = await pool.query(sql, params);
    return pickWeightedRandomMails(rows, safeCount, safeDay);
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

