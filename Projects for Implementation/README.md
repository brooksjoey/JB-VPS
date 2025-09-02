# Wyndham Properties Red Team Campaign - Evilginx2 v3.4.1

## 🎯 Mission Overview

This repository contains the complete toolkit for conducting an **authorized** red team phishing campaign against Wyndham Properties using Evilginx2 v3.4.1. All activities must be conducted within the scope of the signed authorization letter.

## ⚠️ AUTHORIZATION REQUIRED

**CRITICAL:** This toolkit is for authorized security testing only. You must have written permission from Wyndham Properties before proceeding with any activities.

## 📁 File Structure

```
├── config.conf                    # Master configuration file
├── targets.txt                    # Target employee list (populate with real data)
├── phishlets_okta.yaml            # Okta phishlet for Evilginx2
├── okta.html                      # HTML lure template
├── wyndham_redteam_master.sh       # Main campaign controller
├── recon_wyndham.sh                # Reconnaissance script
├── launch_okta_campaign.sh        # Campaign launcher
├── generate_okta_email.sh         # Email template generator
├── deploy_infrastructure.sh       # Infrastructure deployment
├── cleanup_campaign.sh            # Campaign cleanup and data archival
├── monitor_campaign.sh            # Real-time monitoring (auto-generated)
└── README.md                      # This file
```

## 🚀 Quick Start Guide

### 1. Initial Setup

```bash
# Make all scripts executable
chmod +x *.sh

# Configure your campaign settings
nano config.conf
```

**Required Configuration:**
- Update `PHISHING_DOMAIN` with your registered domain
- Configure SMTP settings for email delivery
- Set campaign dates and parameters

### 2. Reconnaissance Phase

```bash
# Run automated reconnaissance
./recon_wyndham.sh

# Review generated intelligence
ls -la recon_output/
```

**Manual Tasks:**
- Perform LinkedIn searches using generated guide
- Populate `targets.txt` with real employee email addresses
- Validate email format patterns

### 3. Infrastructure Deployment

```bash
# Deploy phishing infrastructure
sudo ./deploy_infrastructure.sh

# Follow the post-deployment instructions
# Configure DNS for your phishing domain
# Start Evilginx2 and run the provided commands
```

### 4. Email Campaign Preparation

```bash
# Generate email templates
./generate_okta_email.sh

# Customize templates with your domain
# Test email delivery before campaign launch
```

### 5. Campaign Launch

```bash
# Use the master controller
./wyndham_redteam_master.sh

# Or launch directly
./launch_okta_campaign.sh
```

### 6. Monitoring and Management

```bash
# Monitor campaign activity
./monitor_campaign.sh

# Check logs
tail -f logs_sessions.log
```

### 7. Campaign Cleanup

```bash
# Clean up infrastructure and archive data
./cleanup_campaign.sh

# Follow post-cleanup verification steps
```

## 📋 Campaign Phases

### Phase 1: Reconnaissance
- DNS enumeration for wyndhamhotels.com
- Subdomain discovery
- Email format detection
- Employee profiling via LinkedIn
- Web application fingerprinting

### Phase 2: Infrastructure Setup
- Phishing domain configuration
- Evilginx2 deployment
- SSL certificate setup
- Firewall hardening
- Monitoring implementation

### Phase 3: Lure Development
- Okta-themed phishing emails
- HTML landing pages
- Social engineering pretext
- Target prioritization

### Phase 4: Campaign Execution
- Controlled email delivery
- Session capture and monitoring
- Real-time credential harvesting
- Traffic analysis

### Phase 5: Data Collection
- Credential extraction
- Session token analysis
- User behavior tracking
- Success rate metrics

### Phase 6: Cleanup and Reporting
- Infrastructure decommissioning
- Secure data archival
- Cleanup verification
- Final reporting

## 🎛️ Configuration Guide

### Master Configuration (config.conf)

```ini
[CAMPAIGN]
CAMPAIGN_NAME="wyndham_okta_2024"
TARGET_DOMAIN="wyndhamhotels.com"
PHISHING_DOMAIN="your-domain.com"  # UPDATE THIS

[EMAIL]
SMTP_SERVER="your-smtp-server"     # UPDATE THIS
SMTP_USER="your-username"          # UPDATE THIS
SMTP_PASS="your-password"          # UPDATE THIS
```

### Target List (targets.txt)

Format: `email,firstname,lastname,title,department,priority`

```
john.smith@wyndhamhotels.com,John,Smith,IT Director,IT,HIGH
jane.doe@wyndhamhotels.com,Jane,Doe,CISO,Security,HIGH
```

## 🔧 Technical Requirements

### Prerequisites
- Ubuntu/Debian Linux system
- Evilginx2 v3.4.1 installed at `/opt/evilginx`
- Root/sudo access for infrastructure setup
- Registered domain for phishing
- SMTP server for email delivery
- SSL certificates for phishing domain

### Dependencies
- curl, dig, host (DNS tools)
- iptables, ufw (firewall)
- openssl (cryptography)
- tar, gzip (archival)

## 🛡️ Security Considerations

### Operational Security
- Use dedicated infrastructure for testing
- Implement rate limiting and traffic controls
- Monitor for defensive responses
- Maintain detailed activity logs

### Data Protection
- Encrypt captured credentials immediately
- Implement secure data retention policies
- Use secure communication channels
- Follow organizational data handling procedures

### Legal Compliance
- Maintain current authorization documentation
- Stay within defined scope boundaries
- Report findings through proper channels
- Coordinate with defensive teams as required

## 📊 Email Templates

### Available Templates
1. **Suspicious Login Alert** - High urgency security notification
2. **Password Reset Request** - Account recovery scenario
3. **MFA Setup Requirement** - Compliance-driven security update

### Customization Points
- Phishing domain replacement
- Lure token insertion
- Personalization fields
- Branding alignment

## 🔍 Monitoring and Analytics

### Real-time Metrics
- Email delivery rates
- Click-through rates
- Credential capture success
- Session hijacking effectiveness
- Geographic distribution

### Log Analysis
- HTTP request patterns
- User agent analysis
- Timing correlations
- Defensive tool detection

## 🧹 Cleanup Procedures

### Automatic Cleanup
- Session data archival
- Log file secure deletion
- Phishlet deactivation
- Firewall rule reset

### Manual Verification
- DNS record updates
- SSL certificate revocation
- Email infrastructure shutdown
- Final security sweep

## 📈 Reporting Template

### Executive Summary
- Campaign objectives and scope
- Timeline and methodology
- Key findings and metrics
- Risk assessment and recommendations

### Technical Details
- Infrastructure configuration
- Attack vector analysis
- Defensive capability assessment
- Improvement recommendations

## 🆘 Troubleshooting

### Common Issues
- **DNS Resolution:** Verify domain configuration
- **SSL Errors:** Check certificate installation
- **Email Delivery:** Test SMTP settings
- **Session Capture:** Review phishlet configuration

### Support Resources
- Evilginx2 documentation: https://help.evilginx.com/
- Campaign logs: `./logs/`
- Configuration validation: `./wyndham_redteam_master.sh status`

## 📞 Emergency Procedures

### Campaign Termination
```bash
# Emergency stop
./cleanup_campaign.sh services-only

# Full cleanup
./cleanup_campaign.sh full
```

### Incident Response
1. Document the incident
2. Preserve evidence
3. Notify stakeholders
4. Coordinate defensive response
5. Update procedures

## ✅ Pre-Launch Checklist

- [ ] Authorization letter signed and filed
- [ ] Phishing domain registered and configured
- [ ] DNS records pointing to campaign server
- [ ] SSL certificates installed and tested
- [ ] Evilginx2 properly configured
- [ ] Email templates customized and tested
- [ ] Target list populated and validated
- [ ] Monitoring systems operational
- [ ] Incident response plan activated
- [ ] Campaign timeline documented

## 📝 Notes

- All timestamps are in UTC
- Log retention period: 30 days
- Campaign scope limited to Wyndham Properties employees
- Coordinate with blue team for defensive testing
- Document all findings for final report

---

**Remember:** This is authorized security testing. Maintain professionalism and ethical standards throughout the engagement.

*Last Updated: $(date)*
# Evilginx2-v3.4.1
