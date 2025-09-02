# 🎓 Beginner's Guide to Evilginx2 Phishing Toolkit

## 📚 What Is This?

This is a **supervised learning toolkit** for understanding how phishing attacks work. You'll be learning to use Evilginx2, which is a tool that creates fake websites that look exactly like real login pages (like Okta, Gmail, etc.) to capture usernames and passwords.

**🚨 SUPER IMPORTANT:** This is for **authorized training only**. You must have written permission before using this on any real company. Using this without permission is illegal and can get you in serious trouble!

## 🤔 How Does Phishing Work? (Simple Explanation)

Think of it like this:
1. **Real website**: `okta.com` (where people normally log in)
2. **Fake website**: `okta-security.com` (looks identical but steals passwords)
3. **Email trick**: Send emails that look like they're from IT saying "click here to verify your account"
4. **Victim clicks**: They go to your fake site instead of the real one
5. **Password stolen**: When they type their password, you capture it
6. **Forward to real site**: They get logged into the real site, so they don't suspect anything

## 🎮 The Easy Way: Using the Master Controller

Good news! You don't need to understand everything at once. We've built an **automated controller** that walks you through each step.

### Step 1: Start the Master Controller

```bash
# Make the script runnable
chmod +x wyndham_redteam_master.sh

# Start the easy menu system
./wyndham_redteam_master.sh
```

This script will show you a menu like this:
```
🎮 CAMPAIGN CONTROL MENU

1) Run Reconnaissance
2) Setup Infrastructure 
3) Generate Email Templates
4) Show Pre-Launch Checklist
5) View Campaign Status
6) Exit
```

Just pick a number and press Enter!

## 📁 What Each File Does (In Simple Terms)

### 🎯 Main Controller Files
- **`wyndham_redteam_master.sh`** - The "easy button" that guides you through everything
- **`config.conf`** - Settings file (like your WiFi password file, but for phishing)
- **`targets.txt`** - List of email addresses you want to target

### 🛠️ Setup and Deployment
- **`deploy_infrastructure.sh`** - Sets up your fake website automatically
- **`cleanup_campaign.sh`** - Cleans up everything when you're done

### 📧 Email Creation
- **`generate_okta_email.sh`** - Creates realistic-looking phishing emails
- **`okta.html`** - The fake login page that steals passwords

### 🕵️ Intelligence Gathering
- **`recon_wyndham.sh`** - Finds information about the target company
- **`launch_okta_campaign.sh`** - Actually starts the phishing attack

### 📊 Monitoring and Logs
- **`logs_sessions.log`** - Records everyone who fell for the trick
- **`phishlets_okta.yaml`** - Instructions for how to copy Okta's website

## 🎯 Complete Beginner Walkthrough

### Phase 1: Configuration (5 minutes)
1. **Open the config file**: `nano config.conf`
2. **Change these settings**:
   - `PHISHING_DOMAIN="your-domain.com"` → Put your actual domain here
   - `SMTP_SERVER="your-smtp-server"` → Your email server
   - `SMTP_USER="your-username"` → Your email username
   - `SMTP_PASS="your-password"` → Your email password

### Phase 2: Run Reconnaissance (10 minutes)
```bash
./wyndham_redteam_master.sh
# Choose option 1: Run Reconnaissance
```

**What this does:**
- Finds all websites owned by the target company
- Discovers email patterns (like firstname.lastname@company.com)
- Looks for employees on LinkedIn
- Creates a report of what it found

### Phase 3: Set Up Your Fake Website (15 minutes)
```bash
# Choose option 2: Setup Infrastructure
```

**What this does:**
- Installs the fake Okta website
- Sets up SSL certificates (so it shows the lock icon)
- Configures firewall rules
- Makes sure everything looks legitimate

### Phase 4: Create Phishing Emails (10 minutes)
```bash
# Choose option 3: Generate Email Templates
```

**What this does:**
- Creates 3 types of scary emails:
  - "Suspicious login detected!"
  - "Your password needs to be reset!"
  - "You must set up 2-factor authentication!"

### Phase 5: Add Your Targets (5 minutes)
Edit the file `targets.txt` and add email addresses like this:
```
john.smith@wyndhamhotels.com,John,Smith,IT Director,IT,HIGH
jane.doe@wyndhamhotels.com,Jane,Doe,Manager,HR,MEDIUM
```

### Phase 6: Test Everything (10 minutes)
- Send yourself a test email first
- Click on your own phishing link
- Make sure it captures your fake password
- Check that logs are working

### Phase 7: Launch the Attack
**⚠️ Only do this with permission!**
```bash
# Use the campaign launcher
./launch_okta_campaign.sh
```

## 🔧 Common Problems and Solutions

### Problem: "Permission denied"
**Solution:** 
```bash
chmod +x *.sh
```
This makes all scripts runnable.

### Problem: "Domain not found"
**Solution:** You need to register a domain name first:
1. Buy a domain that sounds legitimate (like `okta-security.com`)
2. Point it to your server's IP address
3. Update `config.conf` with your domain

### Problem: "Evilginx2 not found"
**Solution:** Install Evilginx2 first:
```bash
# Download and install Evilginx2
git clone https://github.com/kgretzky/evilginx2.git
cd evilginx2
make
sudo make install
```

### Problem: "Emails not sending"
**Solution:** Check your email settings in `config.conf`:
- Make sure SMTP server is correct
- Check username and password
- Some email providers need "app passwords" instead of regular passwords

### Problem: "SSL certificate errors"
**Solution:** 
```bash
# Get free SSL certificates
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com
```

## 📊 Understanding the Results

### Session Logs
When someone falls for your phishing attack, you'll see entries like:
```
[2024-01-15 14:30:22] New session: user@company.com
[2024-01-15 14:30:45] Credentials captured: user@company.com:password123
[2024-01-15 14:30:46] Session cookies stolen
```

### Success Metrics
- **Click Rate**: How many people clicked your email
- **Credential Rate**: How many people entered their password
- **Session Rate**: How many people you can now impersonate

## 🛡️ Defense Learning

While you're learning to attack, also think about defense:

### How to Spot Phishing (Teach others this!)
1. **Check the URL carefully** - Is it really `okta.com` or `okta-security.com`?
2. **Look for typos** - Real companies don't send emails with spelling mistakes
3. **Verify independently** - If you get a security email, log in through the normal website
4. **Check sender details** - Real emails come from official addresses

### How Companies Can Protect Themselves
1. **Employee training** - Teach people to spot phishing
2. **Email filtering** - Block suspicious emails automatically
3. **Multi-factor authentication** - Even if passwords are stolen, accounts stay safe
4. **Regular testing** - Run practice phishing campaigns to find weak spots

## 🎓 Learning Resources

### Before You Start
- **Cybersecurity Basics**: Learn about firewalls, SSL, DNS
- **Linux Command Line**: You'll be using terminal commands
- **Networking**: Understand how websites and email work

### Advanced Topics (After mastering basics)
- **Social Engineering**: Psychology of phishing attacks
- **OSINT**: Advanced reconnaissance techniques
- **Evilginx2 Customization**: Creating your own phishlets
- **Post-Exploitation**: What to do after capturing credentials

## ⚠️ Legal and Ethical Guidelines

### ✅ ONLY USE THIS FOR:
- **Authorized penetration testing** (with signed contracts)
- **Educational purposes** (in controlled environments)
- **Testing your own organization** (with management approval)
- **Security research** (responsibly disclosed)

### ❌ NEVER USE THIS FOR:
- **Attacking random companies** without permission
- **Personal gain** or stealing money
- **Harassing individuals**
- **Any illegal activities**

### 📋 Before Every Test
1. Get written authorization
2. Define scope clearly (what you can and can't do)
3. Set up emergency contacts
4. Plan your cleanup procedure
5. Document everything you do

## 🆘 Emergency Procedures

### If Something Goes Wrong
1. **Stop immediately**: `./cleanup_campaign.sh`
2. **Contact your supervisor**: Don't try to fix it alone
3. **Document what happened**: What command did you run?
4. **Preserve evidence**: Don't delete log files

### If You Get Legal Questions
1. **Don't panic**
2. **Show your authorization letter**
3. **Contact your legal team immediately**
4. **Don't discuss details** without lawyer present

## 🎯 Practice Exercises (Start Here!)

### Exercise 1: Setup (Beginner)
1. Install all prerequisites
2. Configure your settings
3. Run the master controller
4. Generate email templates
5. **Don't send anything yet!**

### Exercise 2: Local Testing (Beginner)
1. Set up a fake domain on your local network
2. Send yourself a phishing email
3. Try to capture your own password
4. Verify logs are working

### Exercise 3: Controlled Campaign (Intermediate)
1. Get permission to test 5 coworkers
2. Send them phishing emails
3. Monitor results
4. Create a simple report

### Exercise 4: Full Campaign (Advanced)
1. Research target company
2. Create custom email templates
3. Launch full campaign
4. Analyze results and create professional report

## 📞 Getting Help

### When You're Stuck
1. **Check the logs**: Most problems show up in error messages
2. **Ask your supervisor**: They're there to help you learn
3. **Read error messages carefully**: They usually tell you what's wrong
4. **Search online**: But be careful about what advice you follow

### Good Resources
- **Evilginx2 GitHub**: Official documentation and examples
- **Penetration Testing Communities**: But remember to stay legal!
- **Cybersecurity Training**: Courses that teach ethical hacking

## 🎉 Congratulations!

If you've made it this far, you're learning valuable cybersecurity skills! Remember:

- **Start slow** - Don't rush into complex attacks
- **Stay legal** - Always get permission first
- **Think defense** - Learn to attack so you can better defend
- **Keep learning** - Cybersecurity changes constantly
- **Be ethical** - Use your powers for good!

---

**Final Reminder**: This toolkit is powerful and can cause real damage if misused. Your supervisor is there to help you learn safely and legally. When in doubt, ask questions!

*Happy (ethical) hacking! 🎯*
