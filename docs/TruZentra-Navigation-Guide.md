# TruZentra — Navigation Guide

> **Step-by-Step Guide to the TruZentra AI Banking Agent on Salesforce**

| Capabilities | Languages | Dashboards | Availability |
|---|---|---|---|
| 8 | 3 | 2 | 24/7 AI-Powered |

**Salesforce Agentforce · Financial Services Cloud · Data Cloud 360° · Multilingual AI · Omni-Channel**

---

## Welcome

This guide walks you through every feature of **TruZentra** — an autonomous AI banking concierge built entirely on Salesforce Agentforce, Financial Services Cloud, and Data Cloud. Each section below tells you exactly where to go, what to click, and what to explore.

> ✅ **TruZentra is fully live.** The Salesforce org is provisioned with real sample customers, active AI agent, and all dashboards. Everything you need is ready to use.

---

## Where to Find Everything

| Component | What It Is |
|---|---|
| 🤖 **AI Agent** | Agentforce chat interface — test all 8 self-service capabilities conversationally |
| 📊 **TruZentraOps** | RM Operations Dashboard — Customer 360 console with 7 tabbed data views |
| 🌐 **Data Cloud 360** | Unified Data Cloud profile with real-time churn risk scoring and calculated insights |
| 📧 **Email Inbox** | Open the test customer's registered email to receive OTPs, summaries, and confirmations |

---

## Test Customer & Credentials

Use **Rajesh Sharma** for all steps. All accounts, transactions, disputes, and SIPs are pre-loaded.

| Field | Value |
|---|---|
| Customer Name | Rajesh Sharma |
| Mobile | **8197733966** |
| MPIN | **Use the default MPIN as provided** |
| Accounts | Savings, Credit Card, Home Loan, 7 SIPs, Recurring Payments |

> ⚠️ **Authentication Options:** Mobile is `8197733966`. Use the **MPIN from the default credentials provided**. Alternatively choose OTP — the code will be sent to Rajesh's registered email. If using OTP, open that inbox in a second tab before you begin. OTP expires in 5 minutes.

> 📧 **Want to Experience Emails First-Hand?** To receive OTPs and branded email summaries in your own inbox, navigate to the **Accounts** tab → select the **Zentra Accounts** list view → open **Rajesh Sharma**'s account → edit the **Email** field and replace it with your own email address. All subsequent OTPs, dispute confirmations, loan confirmations, and summary emails will arrive in your inbox.

---

## Step 1 — Log In to the Salesforce Org

1. Navigate to the org URL provided. Log in with the **default credentials as provided**. The org alias is `AF`.
2. Click the **App Launcher** (9-dot grid, top-left) → search for `Zentra Bank` → select the **Zentra Bank** app. This is the central hub for all features.
3. Verify you see the tabs: **TruZentraOps**, **Data Cloud 360**, **Accounts**, **Cases**, **Loan Restructuring**, and **Recurring Payments**.

### App Tabs

| Tab | Purpose |
|---|---|
| 📊 TruZentraOps | Customer 360 Operations Console — the primary RM dashboard |
| 🌐 Data Cloud 360 | Unified customer profile powered by Salesforce Data Cloud |
| 👥 Accounts | Standard Salesforce Person Account records for all customers |
| 📁 Cases | Dispute cases and new account opening request records |
| 🏦 Loan Restructuring | All loan restructuring request records with EMI comparison |
| 🔄 Recurring Payments | Standing instruction records with stop-payment history |

---

## Step 2 — Evaluate the AI Agent (Agentforce)

The core of TruZentra is the **conversational AI banking agent** built on Salesforce Agentforce. You can interact with it directly to verify all 8 self-service capabilities.

> ⚠️ **WhatsApp Integration Note:** The WhatsApp Messaging Setting for TruZentra is configured in the Salesforce org. However, due to **META's platform restrictions**, messages cannot be sent from Agentforce to end users over WhatsApp in this environment. All AI agent interactions are accessible via the Zentra Bank Support portal below.

### How to Open the Agent

1. **Open the Agentforce Chat Portal**  
   Navigate to: **https://orgfarm-165ae77bf1.my.site.com/ZentraBankSupport/**  
   The chat launcher will appear on the page. Click it to open the TruZentra AI agent.

2. **Start a New Conversation**  
   Type `Hi` or `Hello` to begin. The agent will greet and ask for the registered mobile number.

3. ✅ **Authenticate (Required First)**  
   Enter `8197733966` (Rajesh Sharma). The agent will offer OTP or MPIN. For fastest access, choose **MPIN** and enter the **MPIN from the default credentials**. The agent confirms: *"Verified! Welcome Rajesh ji."*

---

## Step 3 — Test All 8 Capabilities

Once authenticated, use the messages below to test each capability.

### Capability 1 — 🔒 RBI-Compliant Authentication
Dual-factor authentication via OTP (email) or MPIN. Session management with lockout protection and full audit trail.  
**Type:** Start with *Hi*, enter `8197733966`, choose MPIN and enter the MPIN from default credentials. Alternatively choose OTP and check Rajesh's registered email.

### Capability 2 — 💰 Balance Check
Real-time balance across all accounts — Savings, Credit Card, and Loan — in a single response.  
**Type:** *"Mera balance dikhao"* (Hinglish) — verify the agent responds in Hinglish and shows all 3 accounts.

### Capability 3 — 📋 Mini-Statement
Recent transaction history with merchant name, amount, date, category, and dispute flag.  
**Type:** *"Show my last transactions"* — verify merchant names, amounts, and categories are all present.

### Capability 4 — ⚠️ One-Message Dispute Filing
Customer names a merchant and amount; AI auto-matches the transaction, files the case, and issues provisional credit — all in one message.  
**Type:** *"Dispute 5000 at Amazon"* — verify case number is returned and provisional credit is issued instantly.

### Capability 5 — 🏦 Loan Restructuring
AI shows loan details, simulates 3 options (extend 12mo / 24mo / 3-month moratorium), collects a second OTP, submits the request, and schedules an RM callback.  
**Type:** *"Meri EMI kam karo"* — verify 3 options with EMI impact are shown. Select one, enter loan OTP, confirm restructuring request and RM callback.

### Capability 6 — 🔄 Recurring Payments
Lists all standing instructions and stops any payment on request with email confirmation.  
**Type:** *"Show recurring payments"* then *"Stop the Netflix one"* — verify cancellation confirmation email arrives.

### Capability 7 — 📈 Mutual Fund / SIP Portfolio
Full portfolio view with fund names, folio numbers, SIP amount, current value, gain/loss, XIRR returns, and investment status per fund.  
**Type:** *"Show my mutual fund portfolio"* — verify fund names (HDFC, ICICI, SBI etc.), invested vs current value, and XIRR are all displayed.

### Capability 8 — 📧 Branded Email Summaries
6 on-demand email types — Balance, Transaction, Dispute, Loan, Recurring, Mutual Fund — all fully branded and triggered by customer request.  
**Type:** *"Send me my loan summary email"* — switch to the email inbox tab and verify the branded email arrives within seconds.

> 💡 **Multilingual Test:** Try the same capability in English, Hindi (Devanagari), and Hinglish to verify automatic language detection and culturally appropriate responses (honorifics like "ji" and "dhanyavaad").

---

## Step 4 — Evaluate TruZentraOps Dashboard

The **TruZentraOps** tab is the Relationship Manager's Customer 360 Operations Console.

1. Click the **TruZentraOps** tab. Type `Rajesh` in the search box and select **Rajesh Sharma**.
2. Verify the **Profile Banner** shows name, contact info, and Total Relationship Value.
3. Verify the **7 KPI Summary Cards**: Total Accounts, Active Recurring, Open Disputes, Loan Requests, Cards, Recent Transactions, Active SIPs.
4. ✅ Click through all **7 tabs**: Accounts → Transactions → Recurring → Loans → Disputes → SIPs/MF → Audit Trail.
5. In **Accounts** tab, try **Freeze Account** / **Reactivate** and **Deactivate All** bulk action.
6. In **Transactions** tab, click the **Dispute** button on any row to file a case directly from the RM console.

| Tab | What to Look For |
|---|---|
| **Accounts** | Savings, Credit Card, and Loan cards with balance, status, Freeze/Reactivate per account |
| **Transactions** | Merchant name, amount, date, category, dispute flag, one-click dispute action |
| **Recurring Payments** | Standing instructions with payee, amount, frequency, and Stop button |
| **Loans** | Restructuring requests — selected option, old vs new EMI, RM callback date |
| **Disputes** | Case stage, disputed amount, provisional credit issued flag, estimated resolution date |
| **SIPs / MF** | Fund name, folio, SIP amount, total invested, current value, units held, installments completed |
| **Audit Trail** | OTP session logs (status, attempts), email delivery logs, error logs with class/method/severity |

---

## Step 5 — Evaluate Data Cloud 360 Dashboard

Navigate to the **Data Cloud 360** tab. This dashboard unifies CRM and external data from 6 Data Lake Objects (DLOs) mapped to DMOs in Salesforce Data Cloud.

1. Type `Rajesh Sharma` (or `8197733966`). Search is case-insensitive.
2. ✅ Verify a real-time **Churn Risk Score (0–100)** is displayed with a visual gauge. A score of 60+ is high risk. This score is computed by a **Calculated Insight** in Data Cloud, not a static field.
3. Verify the **Contributing Factors** breakdown: Open Disputes, Low Transaction Frequency, Recurring Cancelled, and Account Balance — each scored with progress bars.
4. Verify the profile shows aggregated data from multiple sources all in one view powered by Data Cloud.

| Feature | Technical Detail |
|---|---|
| Unified Customer Profile | Data from 6 DLOs merged in Data Cloud — Account, Financial Accounts, Transactions, Disputes, Loans, Recurring |
| Churn Risk Score | Calculated Insight using Data Cloud SQL across 6 DMOs with weighted scoring |
| Contributing Factors | 4 real-time sub-scores: account activity, payment health, dispute volume, transaction frequency |
| Search | Case-insensitive search across Data Cloud DLOs using Apex with `toLowerCase()` matching |

---

## Step 6 — Explore the Data Model

Explore the underlying Salesforce object model to see how TruZentra uses native FSC and custom objects.

1. **Accounts tab** → select **Rajesh Sharma** — Person Account with custom fields: `WhatsApp_Opted_In__c`, `Churn_Score__c`, `Total_Relationship_Value__c`
2. **Financial Accounts** — `FinServ__FinancialAccount__c` records: Savings, Credit Card, Home Loan with `Account_Number_Masked__c`, `Credit_Limit__c`, `Current_EMI__c`, `Interest_Rate__c`
3. **Cases tab** — open any dispute case. Verify: `Dispute_Stage__c`, `Dispute_Amount__c`, `Provisional_Credit_Issued__c`, `Estimated_Resolution_Date__c`
4. **Loan Restructuring tab** — open a record. Verify: `Selected_Option__c`, `Original_EMI__c`, `New_EMI__c`, `RM_Callback_Scheduled__c`
5. **Setup → Agentforce → Agents → TruZentra** — verify 10 topics, 22+ actions, and attribute mapping for `VerifiedCustomerId`

---

## Technical Stack Reference

| Layer | Technology | Usage in TruZentra |
|---|---|---|
| AI Agent | Salesforce Agentforce (GenAI Planner Bundle) | 10 topics, 22+ actions, attribute mapping for verified customer identity |
| Banking Data | Financial Services Cloud (FSC) | `FinServ__FinancialAccount__c`, `FinServ__FinancialAccountTransaction__c`, `FinServ__Card__c` |
| Unified Data | Salesforce Data Cloud | 6 DLOs, 6 DMOs, Calculated Insights for churn risk scoring |
| Automation | Apex + Flows | 41+ Apex service classes, 22 autolaunched/screen flows |
| UI | Lightning Web Components | 10 LWCs incl. TruZentraOps, Data Cloud 360, file upload |
| Configuration | Custom Metadata Types | 2 CMDT types (14 records) for email engine and app config |
| Security | `OTP_Session__c` + Permission Sets | Session tokens, lockout, audit logging, TruZentra Admin permission set |
| AI Enrichment | Einstein OCR + Prompt Templates | Receipt upload and dispute enrichment via ConnectApi / REST fallback |
| Email | `Messaging.SingleEmailMessage` | 14 branded email templates, CMDT-configurable per type |

---

## Quick Test Cheat Sheet

| What to Test | Message to Type | Expected Result |
|---|---|---|
| Balance (Hinglish) | Mera balance dikhao | Agent responds in Hinglish, shows Savings + CC + Loan balances |
| Balance (Hindi) | मेरा बैलेंस दिखाओ | Agent detects Devanagari and responds in Hindi |
| Dispute Filing | Dispute 5000 at Amazon | Case created, provisional credit issued, case number shown |
| Loan Restructuring | Meri EMI kam karo | 3 options shown with EMI comparison; after selection, OTP requested |
| Recurring Payments | Show my standing instructions | All active recurring payments listed with amount and payee |
| Stop a Payment | Cancel the Netflix payment | Confirmation shown; cancellation email sent to customer inbox |
| Mutual Funds | Show my SIP portfolio | All funds with invested vs current value, XIRR, and status |
| Email Summary | Send me my balance summary | Branded balance email delivered to registered inbox in <30 seconds |
| Post-Task Menu | (any task completion) | 8-option menu appears: Balance, Txns, Dispute, Loan, Recurring, MF, Email, MPIN |
| MPIN Login | New session → enter mobile → choose 2 | Authentication without OTP email using MPIN |

---

## Troubleshooting

| Issue | Resolution |
|---|---|
| OTP not arriving in inbox | Check spam/junk folder. Verify the Contact record has the correct email. OTP expires in 5 minutes. |
| Agent not responding | Refresh the browser tab. Confirm the TruZentra agent is published and active in Agentforce Setup. Re-open [the portal](https://orgfarm-165ae77bf1.my.site.com/ZentraBankSupport/). |
| Mobile number not recognised | Try `+918197733966` with the `+91` prefix. The lookup handles both formats. |
| Loan restructuring blocked | A 90-day cooldown is enforced per customer. Reset via the `Is_Restructured__c` field on the Financial Account if needed. |
| Data Cloud dashboard showing no data | The Data Cloud ingestion job may need a manual refresh. Re-run the ingestion from Data Cloud Setup if data is stale. |
| TruZentraOps shows no customer | Confirm the Account record exists with the correct phone in `PersonMobilePhone`. All search uses this field. |

---

> ✅ **All features are live and testable.** TruZentra is deployed on a fully provisioned Salesforce org — not a demo environment or prototype. Every capability, dashboard, and data model element described in this guide is real and executable.

---

*Various trademarks held by their respective owners.*
