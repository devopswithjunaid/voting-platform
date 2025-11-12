const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const port = 4000;

const pool = new Pool({
  connectionString: 'postgres://postgres:postgres@db/postgres'
});

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/api/votes', async (req, res) => {
  try {
    const result = await pool.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote');
    const votes = { a: 0, b: 0 };
    
    result.rows.forEach(row => {
      votes[row.vote] = parseInt(row.count);
    });
    
    res.json(votes);
  } catch (err) {
    console.error('Database query error:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Results app running on port ${port}`);
});
