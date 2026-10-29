import express from 'express';

const app = express();

app.get('/', (req, res) => {
    res.status(200).send('Helloe from Acquisitions!');
});

export default app;