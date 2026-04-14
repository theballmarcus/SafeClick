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

export async function getSpamMails({ count = 5, excludeIds = [] }) {
    const safeCount = Number.isInteger(count) ? count : 5;
    const safeExcludeIds = Array.isArray(excludeIds)
        ? excludeIds.filter((id) => Number.isInteger(id) && id > 0)
        : [];

    const baseSql = `SELECT id, subject, sender_name, sender_email, body, real_url, is_phishing, hint, difficulty, category, created_at
        FROM unique_mails
        WHERE is_phishing = 1`;

    const orderingSql = ` ORDER BY FIELD(difficulty, 'easy', 'medium', 'hard'), id ASC LIMIT ?`;

    let sql = baseSql + orderingSql;
    let params = [safeCount];

    if (safeExcludeIds.length > 0) {
        const placeholders = safeExcludeIds.map(() => '?').join(', ');
        sql = `${baseSql} AND id NOT IN (${placeholders})${orderingSql}`;
        params = [...safeExcludeIds, safeCount];
    }

    const [rows] = await pool.query(sql, params);
    return rows;
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
        const [result] = await pool.query(sql, [
            mail.subject,
            mail.sender_name ?? null,
            mail.sender_email ?? null,
            mail.body,
            mail.real_url ?? null,
            1,
            mail.hint ?? null,
            mail.difficulty,
            mail.category ?? 'generated'
        ]);
        insertedCount += result.affectedRows || 0;
    }

    return insertedCount;
}

export async function getHighscores() {
    const [rows] = await pool.query(
        'SELECT username, highscore, created_at FROM highscore ORDER BY highscore DESC LIMIT 10');
    if (!rows || rows.length === 0) return null;
    const r = rows[0];
    return { 
        username: r.username,
        highscore: parseInt(r.highscore),
        created_at: r.created_at
    };
}

export async function getAllMails() {
    const [rows] = await pool.query('SELECT id, subject, sender_name, sender_email, body, real_url, is_phishing, hint, difficulty, category, created_at FROM unique_mails');
    return rows;
}

