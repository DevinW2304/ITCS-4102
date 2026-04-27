# Fraud Detection Using Julia
**ITCS 4102 — Final Project**
Devin Washington, Angel Villar Nolasco, Lavishia Crump

## Prerequisites

Make sure the following are installed before running the project:

- [Node.js](https://nodejs.org/) v18 or later
- [Julia](https://julialang.org/downloads/) v1.9 or later (must be on your system `PATH`)

To verify both are available, run:
```bash
node --version
julia --version
```

---

## Dataset Setup

This project uses the [PaySim synthetic financial dataset](https://www.kaggle.com/datasets/ealaxi/paysim1).

1. Download `PS_20174392719_1491204439457_log.csv` from Kaggle.
2. Rename it to `paysimFile.csv`.
3. Place it in a `dataset/` folder in the project root:

```
dataset/
└── paysimFile.csv
```

---

## How to Run Locally

### 1. Install Node Dependencies

```bash
npm install
```

### 2. Start the Server

```bash
npm start
```

The server will start at `http://localhost:3000`.

### 3. Open the Dashboard

Open your browser and go to:

```
http://localhost:3000
```

### 4. Run the Analysis

Click the **"Run Demo"** button in the top-right of the dashboard. The server will invoke the Julia script against the CSV, parse the output, and populate the dashboard with results.

---

## Running Julia Standalone (No Server)

You can run the Julia script directly without the web frontend:

```bash
# Using the sample data built into the script
julia fraud_detection_demo.jl

# Using the CSV
julia fraud_detection_demo.jl dataset/paysimFile.csv 20000 100000 200
```
   Arguments: `<csv_path> <max_rows> <threshold> <max_print>`


---

## Dependencies

**Node.js**
- `express` — web server
- `cors` — cross-origin support
- `multer` — multipart handling

**Julia**
- `Statistics` (standard library) — for `mean()`

Install Node dependencies with `npm install`. 