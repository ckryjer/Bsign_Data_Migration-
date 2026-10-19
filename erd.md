# bSign Reporting ERD (draft)

Source: 10/19/2026 check-in (Christian's proposed model) plus the columns kept from `dbo.signature_requests_raw`.
Renders on GitHub, in VS Code preview, or by pasting the block into mermaid.live.

```mermaid
erDiagram
    ACCOUNT ||--o{ BSIGN_REQUESTER_EMAIL : "has"
    ACCOUNT ||--o{ BSIGN_CONTRACT : "has"
    ACCOUNT ||--o{ BSIGN_USAGE_RECORD : "has"
    BSIGN_CONTRACT ||--o{ BSIGN_USAGE_RECORD : "covers"
    BSIGN_REQUESTER_EMAIL ||..o{ BSIGN_USAGE_RECORD : "pipeline match only"

    ACCOUNT {
        id Id PK
        string Name "the client"
    }
    BSIGN_REQUESTER_EMAIL {
        id Id PK
        string Email_Address
        id Account FK "lookup"
    }
    BSIGN_CONTRACT {
        id Id PK
        id Account FK "lookup"
        date Start_Date
        date End_Date
        int Purchased_Quantity "proposed"
        string Notes
    }
    BSIGN_USAGE_RECORD {
        id Id PK
        string Signature_Request_ID UK "from Dropbox Sign"
        id Account FK "lookup"
        id Contract FK "lookup"
        string Requester_Email
        string Sent_From_Domain
        string Client_ID
        datetime Created_At
        datetime Signed_At
        datetime Expires_At
        boolean Is_Complete
        boolean Is_Declined
        boolean Has_Error
        boolean Test_Mode
        string Title
        string Subject
    }
```

## Reading it

- Each box is an object (a table). The fork end of a line is the "many" side, and that side holds the lookup field.
- The dashed line means no lookup exists. The pipeline uses the Requester Email table to find the Account, then sets the Account lookup on the usage record.
- `Purchased_Quantity` is proposed (not in the 10/19 field list). Needed to compare usage to what was bought.
- Open decision: custom bSign Contract object vs. the standard Salesforce Contract with a Type field.
