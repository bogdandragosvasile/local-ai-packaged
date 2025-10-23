# Keycloak Visual Navigation Guide

This guide uses ASCII diagrams to help you navigate Keycloak's admin console.

## Navigation Map

```
┌─────────────────────────────────────────────────────────────────┐
│  https://keycloak.mylegion5pro.me/admin                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Keycloak Admin Console                                   │  │
│  │  Realm: homelab ▼                                         │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │ Left Sidebar Menu:                                  │  │  │
│  │  │ ├─ Manage (collapse/expand)                         │  │  │
│  │  │ │  ├─ Groups            ← CREATE GROUPS HERE        │  │  │
│  │  │ │  ├─ Users             ← CREATE USERS HERE         │  │  │
│  │  │ │  ├─ Roles                                         │  │  │
│  │  │ │  └─ Clients           ← VERIFY CLIENTS HERE       │  │  │
│  │  │ ├─ Configure                                        │  │  │
│  │  │ │  ├─ Client Scopes    ← MAP GROUP CLAIMS (opt)    │  │  │
│  │  │ │  ├─ Clients                                       │  │  │
│  │  │ │  └─ Mappers                                       │  │  │
│  │  │ └─ Realm Settings     ← GENERAL CONFIG              │  │  │
│  │  │                                                     │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Create Groups

```
┌─────────────────────────────────────────────────┐
│ Manage → Groups                                 │
├─────────────────────────────────────────────────┤
│ [Create group button]                           │
│                                                 │
│ Groups list:                                    │
│ ├─ [ ] admins          ← First group            │
│ ├─ [ ] developers       ← Second group          │
│ ├─ [ ] explorers        ← Third group           │
│ └─                                              │
│                                                 │
│ When you click each group:                      │
│ ├─ Name: admins                                 │
│ ├─ Parent: (none)                               │
│ ├─ Members: (empty)                             │
│ └─ [Save]                                       │
└─────────────────────────────────────────────────┘
```

---

## Step 2: Create Users

```
┌──────────────────────────────────────────────────────────┐
│ Manage → Users                                           │
├──────────────────────────────────────────────────────────┤
│ [Create new user button]                                 │
│                                                          │
│ ┌────────────────────────────────────────────────────┐   │
│ │ Create User Form:                                  │   │
│ │ Username:      [ admin         ]                   │   │
│ │ Email:         [ admin@ex.com  ]  ☑ Verified     │   │
│ │ First Name:    [ Admin         ]                   │   │
│ │ Last Name:     [ User          ]                   │   │
│ │ Enabled:       ☑ ON                                │   │
│ │                    [Create]                        │   │
│ └────────────────────────────────────────────────────┘   │
│                                                          │
│ After creating user, you'll see tabs:                    │
│ │ Details │ Credentials │ Groups │ Attributes │...      │
│ └──────────────────────────────────────────────────     │
└──────────────────────────────────────────────────────────┘
```

---

## Step 3: Set User Password

```
┌────────────────────────────────────────────┐
│ Users → (select user) → Credentials tab    │
├────────────────────────────────────────────┤
│ Password Credentials:                      │
│ ┌──────────────────────────────────────┐   │
│ │ [Set Password] button                │   │
│ │                                      │   │
│ │ Password: [ ········· ]              │   │
│ │ Confirmation: [ ········· ]          │   │
│ │ Temporary: ☑ ON (toggle to OFF!)    │   │
│ │                                      │   │
│ │ [Set Password] [Cancel]              │   │
│ └──────────────────────────────────────┘   │
│                                            │
│ After setting:                             │
│ ✅ "Password updated" message             │
└────────────────────────────────────────────┘
```

---

## Step 4: Assign User to Group

```
┌────────────────────────────────────────────┐
│ Users → (select user) → Groups tab         │
├────────────────────────────────────────────┤
│ Groups: (current groups)                   │
│ │                                          │
│ │ Available Groups:                        │
│ │ ├─ [ ] admins                            │
│ │ ├─ [ ] developers                        │
│ │ └─ [ ] explorers                         │
│ │                                          │
│ │ (click group, then [Join] button)        │
│ │                                          │
│ │ Selected group will move to top:         │
│ │ Groups:                                  │
│ │ ├─ ⊗ admins    ← Now assigned!           │
│ │                                          │
│ └──────────────────────────────────────────┘
│ [Save] (if needed)                         │
└────────────────────────────────────────────┘
```

---

## Step 5: Verify OAuth Clients

```
┌──────────────────────────────────────────────┐
│ Configure → Clients                          │
├──────────────────────────────────────────────┤
│ Clients list:                                │
│ ├─ [ ] flowise      ← Click to verify        │
│ ├─ [ ] n8n                                   │
│ ├─ [ ] neo4j                                 │
│ ├─ [ ] oauth2-proxy                          │
│ └─ [ ] searxng                               │
│                                              │
│ When you click a client (e.g., flowise):     │
│ ┌──────────────────────────────────────────┐ │
│ │ Client ID: flowise                       │ │
│ │ Access Type: confidential                │ │
│ │ Valid Redirect URIs:                     │ │
│ │ └─ https://flowise.lupulup.com/auth/...  │ │
│ │ Web Origins:                             │ │
│ │ └─ https://flowise.lupulup.com           │ │
│ │ PKCE Code Challenge: S256 ✅             │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

---

## Step 6: Add Groups to Token (Optional)

```
┌────────────────────────────────────────────┐
│ Configure → Client Scopes                  │
├────────────────────────────────────────────┤
│ Available Client Scopes:                    │
│ ├─ [ ] api                                  │
│ ├─ [ ] email                                │
│ ├─ [ ] profile                              │
│ ├─ [x] roles        ← Click this one        │
│ └─                                          │
│                                            │
│ Roles Scope page:                           │
│ ├─ Details tab                              │
│ ├─ Scope tab                                │
│ └─ Mappers tab  ← Click here                │
│                                            │
│ Mappers tab:                                │
│ ├─ [Add mapper] dropdown                    │
│ │  └─ Select "Group Membership"             │
│ │     Name: groups                          │
│ │     Token Claim Name: groups              │
│ │     Add to ID token: ☑                    │
│ │     Add to access token: ☑                │
│ │     Add to userinfo: ☑                    │
│ │     [Save]                                │
│ └─                                          │
└────────────────────────────────────────────┘
```

---

## User Creation Workflow

```
                         START
                           │
                           ▼
                    ┌──────────────┐
                    │ Visit Keycloak│
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────────┐
                    │ Select "homelab"  │
                    │ realm             │
                    └──────┬────────────┘
                           │
                           ▼
                    ┌──────────────────┐
                    │ Create 3 Groups:  │
                    │ - admins          │
                    │ - developers      │
                    │ - explorers       │
                    └──────┬────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
   ┌─────────┐        ┌─────────┐        ┌─────────┐
   │ Admin   │        │Developer│        │Explorer │
   │ User    │        │ User    │        │ User    │
   └────┬────┘        └────┬────┘        └────┬────┘
        │                  │                  │
   Create &           Create &            Create &
   Assign to         Assign to           Assign to
   "admins"          "developers"        "explorers"
        │                  │                  │
        ▼                  ▼                  ▼
   username:         username:           username:
   admin             developer           explorer
   pass:             pass:               pass:
   Admin@123!        Dev@123!            Explorer@123!
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                    ┌──────────────────┐
                    │ Test Services:   │
                    │ - Flowise        │
                    │ - n8n            │
                    │ - Neo4j          │
                    │ - SearXNG        │
                    └──────┬───────────┘
                           │
                           ▼
                         END
```

---

## Keycloak Admin Console Sections

```
┌──────────────────────────────────────────────────────────┐
│                    KEYCLOAK ADMIN CONSOLE                │
│                                                          │
│  Top-Left Dropdown: [homelab realm] ▼                    │
│  Top-Right: [Users icon] [? Help] [⚙ Settings]          │
│                                                          │
│  LEFT SIDEBAR:                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Manage (expandable)                                │  │
│  │  ├─ Groups              USER & GROUP MANAGEMENT    │  │
│  │  ├─ Users               (Where you spend most time)│  │
│  │  ├─ Roles                                          │  │
│  │  └─ Clients                                        │  │
│  │                                                    │  │
│  │ Configure (expandable)                             │  │
│  │  ├─ Client Scopes      ADVANCED CONFIG             │  │
│  │  ├─ Clients             (For OAuth/OIDC tuning)    │  │
│  │  └─ Mappers                                        │  │
│  │                                                    │  │
│  │ Realm Settings         REALM-WIDE SETTINGS         │  │
│  │                         (Email, password policy)   │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  MAIN CONTENT AREA: (changes based on menu selection)   │
│  ┌────────────────────────────────────────────────────┐  │
│  │                                                    │  │
│  │ (Displays list, details, or form)                 │  │
│  │                                                    │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

## Service Testing URLs

```
After creating users, test these URLs:

SERVICE TESTS:
├─ Flowise:
│  URL: https://flowise.lupulup.com
│  Try login: admin / Admin@123!
│  Expected: Flowise interface loads, you're logged in
│
├─ n8n:
│  URL: https://n8n.lupulup.com
│  Try login: admin (internal n8n user)
│  Expected: n8n editor loads
│
├─ Neo4j Browser:
│  URL: https://neo4j.lupulup.com
│  Try login: neo4j / neo4j_secure_123
│  Expected: Neo4j Browser interface loads
│
└─ SearXNG:
   URL: https://searxng.lupulup.com
   Expected: Search interface loads (no login needed)
```

---

## Common Next Clicks

```
Task: Create Groups
├─ Click: Manage (left sidebar)
├─ Click: Groups (in submenu)
├─ Click: [Create group] button
├─ Enter: Group name (e.g., "admins")
└─ Click: [Create]

Task: Create User
├─ Click: Manage (left sidebar)
├─ Click: Users (in submenu)
├─ Click: [Create new user] button
├─ Fill: Username, Email, First/Last Name
├─ Toggle: Enabled = ON
└─ Click: [Create]

Task: Set User Password
├─ In User Details page, Click: Credentials tab
├─ Click: [Set password] button
├─ Enter: Password twice
├─ Toggle: Temporary = OFF
└─ Click: [Set password]

Task: Assign User to Group
├─ In User Details page, Click: Groups tab
├─ In Available Groups: Click desired group
├─ Click: [Join] button
└─ Group moves to top (now assigned)
```

---

## Keyboard Shortcuts & Tips

```
Tips for faster navigation:

1. After creating a user, stays on same page
   → Click "Credentials" tab immediately
   → Set password without leaving

2. After setting password, groups tab is next
   → Click "Groups" tab
   → Assign user to group
   → Click [Save] to finish

3. To create multiple users quickly:
   → After creating first user
   → Go back to Users list
   → Click [Create new user] again
   → Repeat process

4. Browser tabs for faster workflow:
   → Tab 1: Manage Groups
   → Tab 2: Manage Users
   → Tab 3: Configure Clients
   → Switch between tabs as needed
```

---

## Keyboard Shortcuts (if available)

```
Most modern browsers support:
Ctrl+L or Cmd+L   → Jump to URL bar
F5                → Refresh page
Ctrl+Shift+Delete → Clear browser cache (if login issues)
```

---

See `KEYCLOAK-USER-SETUP-GUIDE.md` for full detailed instructions.
