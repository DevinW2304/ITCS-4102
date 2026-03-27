const express = require("express");
const cors = require("cors");
const { execFile } = require("child_process");
const path = require("path");

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

app.post("/analyze", (req, res) => {
  const juliaPath = path.resolve(__dirname, "fraud_detection_demo.jl");
  const csvPath = path.resolve(__dirname, "dataset", "paysimFile.csv");

  execFile("julia", [juliaPath, csvPath], (error, stdout, stderr) => {
    if (error) {
      console.error("Julia error:", stderr || error.message);
      return res.status(500).json({
        error: "Julia script failed.",
        details: stderr || error.message
      });
    }

    try {
      const parsed = parseJuliaOutput(stdout);
      res.json(parsed);
    } catch (parseError) {
      console.error("Parse error:", parseError);
      console.error("Raw Julia output:\n", stdout);
      res.status(500).json({
        error: "Could not parse Julia output.",
        rawOutput: stdout
      });
    }
  });
});

function matchNumber(text, regex) {
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

  const classifications = [];
  const lines = output.split("\n");

  for (const line of lines) {
    const trimmed = line.trim();

    if (!trimmed.startsWith("step=")) continue;

    const match = trimmed.match(
      /step=(\d+)\s+type=([A-Z_]+)\s+amount=([\d.]+)\s+orig=([^\s]+)\s+dest=([^\s]+)\s+isFraud=(true|false)/
    );

    if (match) {
      classifications.push({
        step: Number(match[1]),
        type: match[2],
        amount: Number(match[3]),
        nameOrig: match[4],
        nameDest: match[5],
        isFraud: match[6] === "true"
      });
    }
  }

  return {
    transactionsProcessed,
    uniqueCustomers,
    fraudCount,
    suspiciousCount,
    suspiciousTransferCount,
    classifications
  };
}

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});