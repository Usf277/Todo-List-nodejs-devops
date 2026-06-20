const express = require('express');
const port = process.env.PORT || 4000;
const path = require('path');
const promClient = require('prom-client');

// require the mongoose file
const db = require('./config/mongoose');
const User = require('./models/register');
const Login = require('./models/login');
const Dashboard = require('./models/dashboard');

const app = express();

// ── Prometheus metrics ────────────────────────────────────────────────────────
// Collect default Node.js process metrics: heap, CPU, event loop lag, GC, etc.
promClient.collectDefaultMetrics();

// Track HTTP request duration per method/route/status
const httpRequestDuration = new promClient.Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request latency in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.05, 0.1, 0.3, 0.5, 1, 1.5, 2, 5]
});

// Duration middleware must be registered before any route handlers
app.use((req, res, next) => {
    const end = httpRequestDuration.startTimer();
    res.on('finish', () => {
        end({
            method: req.method,
            route: req.route ? req.route.path : req.path,
            status_code: res.statusCode
        });
    });
    next();
});

// Expose /metrics for Prometheus scraping (ServiceMonitor targets this endpoint)
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
});
// ─────────────────────────────────────────────────────────────────────────────

// path: routes\index.js
app.get('/', require('./routes'));
app.get('/dashboard', require('./routes'));
app.get('/register', require('./routes'));
app.get('/alltask', require('./routes'));
app.get('/completedtask', require('./routes'));

// set up the view engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// set up the middleware
app.use(express.urlencoded());

// set up the static files
app.use(express.static('assets'));


// registering the user in the database
app.post('/register', (req, res) => {
    User.create({
        name: req.body.name,
        lastName: req.body.lastName,
        phone: req.body.phone,
        email: req.body.email,
        password: req.body.password
    })
    .then(user => {
        console.log("Successfully Created user!", user);
        res.redirect('/dashboard');
    })
    .catch(err => {
        console.log("Error Creating user!!", err);
        res.status(500).send("Error Creating user!!");
    });
});

// adding the task to the database
app.post('/addtask', function(req,res){
    Dashboard.create({
        task : req.body.task,
        date : req.body.date,
        description : req.body.description,
        time : req.body.time,
        categoryChoosed : req.body.categoryChoosed
    })
    .then(newTask => {
        console.log("Successfully Created Task!", newTask);
        res.redirect('back');
    })
    .catch(err => {
        console.log("Error Creating Task!!", err);
        res.redirect('back');
    });
});

// complate the task to the database
app.get('/complete-task', function(req,res){
    let id = req.query.id;
    Dashboard.findByIdAndUpdate(id, {completed: true})
    .then(newTask => {
        console.log("Successfully Complated Task!", newTask);
        res.redirect('back');
    })
    .catch(err => {
        console.log("Error Complating Task!!", err);
        res.redirect('back');
    });
});


// deleting the task to the database
app.get('/delete-task', function(req,res){
    let id = req.query.id;
    Dashboard.findByIdAndDelete(id)
    .then(newTask => {
        console.log("Successfully Deleted Task!", newTask);
        res.redirect('back');
    })
    .catch(err => {
        console.log("Error Deleting Task!!", err);
        res.redirect('back');
    });

});


app.listen(port,(err) => {
    if (err) {
        console.log(`Error: ${err}`);
    }
    console.log(`Yupp! Server is running on port ${port}`);
})
