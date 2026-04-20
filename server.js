const express = require("express");
const cors = require("cors");
const { execFile } = require("child_process");
const path = require("path");

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

console.log("Starting Express server...");
console.log("__dirname:", __dirname);

app.post("/analyze", (req, res) => {
  console.log("POST /analyze route was hit");
  console.log("Request body:", req.body);

  const juliaPath = path.resolve(__dirname, "fraud_detection_demo.jl");
  const csvPath = path.resolve(__dirname, "dataset", "paysimFile.csv");

  const maxRows =
    req.body && req.body.maxRows ? String(req.body.maxRows) : "20000";

  const threshold =
    req.body && req.body.threshold ? String(req.body.threshold) : "100000";

  const maxPrint =
    req.body && req.body.maxPrint ? String(req.body.maxPrint) : "200";

  console.log("\n================ ANALYZE REQUEST ================");
  console.log("Julia file:", juliaPath);
  console.log("CSV file:", csvPath);
  console.log("maxRows:", maxRows);
  console.log("threshold:", threshold);
  console.log("maxPrint:", maxPrint);
  console.log("================================================\n");

  execFile(
    "julia",
    [juliaPath, csvPath, maxRows, threshold, maxPrint],
    { maxBuffer: 20 * 1024 * 1024 },
    (error, stdout, stderr) => {
      console.log("Julia callback reached");

      console.log("\n================ JULIA RAW OUTPUT ================");
      console.log("stdout length:", stdout ? stdout.length : 0);
      console.log("stderr length:", stderr ? stderr.length : 0);

      if (stdout) {
        console.log("\n--- STDOUT START ---");
        console.log(stdout);
        console.log("--- STDOUT END ---\n");
      }

      if (stderr) {
        console.log("\n--- STDERR START ---");
        console.log(stderr);
        console.log("--- STDERR END ---\n");
      }

      console.log("=================================================\n");

      if (error) {
        console.error("Julia error object:", error);
        console.error("Julia error:", stderr || error.message);
        return res.status(500).json({
          error: "Julia script failed.",
          details: stderr || error.message
        });
      }

      try {
        const parsed = parseJuliaOutput(stdout);

        console.log("\n================ PARSED RESPONSE ================");
        console.log(JSON.stringify(parsed, null, 2));
        console.log("================================================\n");

        res.json(parsed);
      } catch (parseError) {
        console.error("Parse error:", parseError);
        console.error("Raw Julia output:\n", stdout);
        res.status(500).json({
          error: "Could not parse Julia output.",
          rawOutput: stdout
        });
      }
    }
  );
});

function matchNumber(text, regex) {
  const match = text.match(regex);
  return match ? Number(match[1]) : 0;
}

function matchFloat(text, regex) {
  const match = text.match(regex);
  return match ? Number(match[1]) : 0;
}

function parseJuliaOutput(output) {
  const transactionsProcessed = matchNumber(
    output,
    /Transactions processed:\s*(\d+)/
  );

  const uniqueCustomers = matchNumber(
    output,
    /Unique customers \(nameOrig\):\s*(\d+)/
  );

  const fraudCount = matchNumber(
    output,
    /Fraud labels in data \(isFraud==1\):\s*(\d+)/
  );

  const suspiciousCount = matchNumber(
    output,
    /Suspicious by rule:\s*(\d+)/
  );

  const suspiciousTransferCount = matchNumber(
    output,
    /Suspicious that are TRANSFER:\s*(\d+)/
  );

  const thresholdUsed = matchFloat(
    output,
    /Threshold used:\s*([\d.]+)/
  );

  const classificationRowsReturned = matchNumber(
    output,
    /Classification rows returned:\s*(\d+)/
  );

  const classificationRowsAvailable = matchNumber(
    output,
    /Classification rows available:\s*(\d+)/
  );

  const highRiskCount = matchNumber(
    output,
    /High risk count:\s*(\d+)/
  );

  const mediumRiskCount = matchNumber(
    output,
    /Medium risk count:\s*(\d+)/
  );

  const lowRiskCount = matchNumber(
    output,
    /Low risk count:\s*(\d+)/
  );

  const truePositives = matchNumber(
    output,
    /True Positives:\s*(\d+)/
  );

  const falsePositives = matchNumber(
    output,
    /False Positives:\s*(\d+)/
  );

  const trueNegatives = matchNumber(
    output,
    /True Negatives:\s*(\d+)/
  );

  const falseNegatives = matchNumber(
    output,
    /False Negatives:\s*(\d+)/
  );

  const precision = matchFloat(
    output,
    /Precision:\s*([\d.]+)/
  );

  const recall = matchFloat(
    output,
    /Recall:\s*([\d.]+)/
  );

  const accuracy = matchFloat(
    output,
    /Accuracy:\s*([\d.]+)/
  );

  const classifications = [];
  const lines = output.split("\n");

  for (const line of lines) {
    const trimmed = line.trim();

    if (!trimmed.startsWith("step=")) continue;

    const match = trimmed.match(
      /step=(\d+)\s+type=([A-Z_]+)\s+amount=([\d.]+)\s+orig=([^\s]+)\s+dest=([^\s]+)\s+isFraud=(true|false)\s+score=(\d+)\s+risk=([A-Z]+)\s+reasons=([A-Za-z0-9_|-]*)/
    );

    if (match) {
      classifications.push({
        step: Number(match[1]),
        type: match[2],
        amount: Number(match[3]),
        nameOrig: match[4],
        nameDest: match[5],
        isFraud: match[6] === "true",
        score: Number(match[7]),
        risk: match[8],
        reasons: match[9] ? match[9].split("|").filter(Boolean) : []
      });
    }
  }

  return {
    transactionsProcessed,
    uniqueCustomers,
    fraudCount,
    suspiciousCount,
    suspiciousTransferCount,
    thresholdUsed,
    classificationRowsReturned,
    classificationRowsAvailable,
    highRiskCount,
    mediumRiskCount,
    lowRiskCount,
    truePositives,
    falsePositives,
    trueNegatives,
    falseNegatives,
    precision,
    recall,
    accuracy,
    classifications
  };
}

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});