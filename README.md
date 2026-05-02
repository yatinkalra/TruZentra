# TruZentra

**AI-Powered Banking Assistant** built on Salesforce Agentforce & Financial Services Cloud.

---

## Navigation Guide

To navigate to the **TruZentra Navigation Guide**, [click here](https://github.com/yatinkalra/TruZentra/blob/main/docs/TruZentra-Navigation-Guide.md)

---

## Overview

TruZentra is a conversational AI banking agent that handles real customer transactions end-to-end — from balance checks to loan restructuring — in English, Hindi, and Hinglish. Built entirely on Salesforce's platform with Agentforce, Financial Services Cloud, and Data Cloud.

---

## Capabilities

| # | Capability | Description |
|---|-----------|-------------|
| 1 | **Authentication** | Dual-factor: OTP (email) + MPIN, RBI-compliant, lockout protection |
| 2 | **Balance & Transactions** | Instant balance across all accounts + categorised mini-statement |
| 3 | **Dispute Management** | One-message filing, auto transaction match, provisional credit, receipt OCR |
| 4 | **Loan Restructuring** | 3-option simulation, OTP confirmation, 90-day cooldown, RM callback |
| 5 | **Recurring Payments** | View and stop standing instructions with confirmation emails |
| 6 | **Mutual Fund / SIP** | Portfolio view with fund details, current value, XIRR returns |
| 7 | **Email Summaries** | 6 types of branded, CMDT-configurable email summaries |
| 8 | **MPIN Management** | Change MPIN with OTP verification gate |

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| AI Agent | Salesforce Agentforce (GenAI Planner Bundle) |
| CRM | Financial Services Cloud (FSC) |
| Data | Salesforce Data Cloud + Calculated Insights |
| Backend | 41+ Invocable Apex Services |
| Automation | 22 Autolaunched Flows |
| UI | 10 Lightning Web Components |
| Email | CMDT-Driven Branded Email Engine (14 templates) |
| Security | OTP + MPIN dual-factor, session tokens, lockout |

---

## Project Structure

```
/
  force-app/main/default/
    classes/           # 41+ Apex services & test classes
    flows/             # 22 Autolaunched & Screen Flows
    lwc/               # 10 Lightning Web Components
    objects/           # Custom objects & field extensions
    customMetadata/    # Zentra_Email_Config__mdt, Zentra_AI_Config__mdt
    genAiPlannerBundles/TruZentra/  # Agent planner bundle & topic configs
    genAiPromptTemplates/           # AI prompt templates
    flexipages/        # App/Record pages
    permissionsets/    # Zentra Bank Admin
    pages/             # Visualforce (session helper)
    remoteSiteSettings/  # Self-callout for AI OCR
    dataStreamDefinitions/  # Data Cloud streams
    mktCalcInsightObjectDefs/  # Churn risk calculated insight
  docs/          # All project documentation
  sfdx-project.json
```

---

## Deployment

### Prerequisites
- Salesforce CLI (`sf`) installed
- Target org with Financial Services Cloud enabled
- Data Cloud provisioned (for 360 dashboard & churn insights)

### Deploy
```bash
sf project deploy start --source-dir  --target-org TruZentra
```

### Setup Test Data
```bash
sf apex run --file scripts/setup-customer.apex --target-org TruZentra
```

The `ZentraSetupCustomer.run(firstName, lastName, email, phone)` method creates a full customer profile with:
- Account & Contact
- 3 Financial Accounts (Savings, Credit Card, Loan)
- 10+ Transactions per account
- 8 Recurring Payments
- 7 SIP/Mutual Fund Holdings
- Credit Card details

---

## Dashboards

| Dashboard | Component | Description |
|-----------|-----------|-------------|
| **TruZentraOps** | `zentraRMDashboard` | Customer 360 Operations Console for RMs |
| **Data Cloud 360** | `zentraDataCloudDashboard` | Unified customer view from Data Cloud with churn score |

---

## Security

- **OTP:** 6-digit, 5-minute expiry, 3-attempt lockout, 30-minute cooldown
- **MPIN:** 4-digit PIN, 3-attempt lockout, login notification email
- **Loan OTP:** Separate verification for high-value loan submissions
- **Data Scoping:** All queries filtered by VerifiedCustomerId
- **Audit Trail:** OTP sessions, email logs, error logs

---

## Languages

- **English** — Full banking conversations
- **Hindi** — Devanagari script with cultural honorifics
- **Hinglish** — Mixed-language natural understanding

---

## Documentation

All documentation is in `/docs/`

---

## Team

**BlueForce Team**

- [Anjali Modi](https://www.linkedin.com/in/anjali-khandelwal-b44b031a/)
- [Sumitra Kumari](https://www.linkedin.com/in/sumitra-kumari-97702391/)
- [Yatin Kalra](https://www.linkedin.com/in/yatin-kalra/)
---
