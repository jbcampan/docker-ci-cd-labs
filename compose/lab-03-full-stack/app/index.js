const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());
const PORT = process.env.PORT || 3000;

// PostgreSQL connection pool
const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Health check endpoint — used by Docker healthcheck
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ok', db: 'reachable' });
  } catch (err) {
    res.status(503).json({ status: 'error', db: 'unreachable', detail: err.message });
  }
});

// List all items
app.get('/items', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM items ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create an item

app.post('/items', async (req, res) => {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: 'name is required' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO items (name) VALUES ($1) RETURNING *',
      [name]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Root
app.get('/', (req, res) => {
  res.json({ message: 'lab03 API is running', endpoints: ['/health', '/items'] });
});

app.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});