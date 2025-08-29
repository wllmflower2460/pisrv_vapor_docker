# DataDogs EdgeInfer System - Trainer Operation Guide

**System**: Portable AI-powered behavioral analysis for professional dog training  
**Hardware**: Raspberry Pi 5 + GL-XE300 LTE Router + iPhone/iPad  
**Purpose**: Real-time detection of K=12 behavioral motifs and handler-dog synchrony analysis

---

## 🚀 Quick Start (5 Minutes)

### 1. **Power On System**
- Connect GL-XE300 router to power (12V adapter)
- Connect Raspberry Pi to power (USB-C adapter)
- Wait 3-4 minutes for full startup (blue LED on router = ready)

### 2. **Connect iPhone/iPad**
- Connect to WiFi network: `DataDogs-Field-[Location]`
- Password: `[Provided by technical team]`
- Open DataDogs app

### 3. **Start Training Session**
- Tap "Start New Session" in app
- System shows: "Connected to EdgeInfer at 192.168.8.241"
- Begin training - behavioral analysis runs automatically!

---

## 📱 Using the iOS App

### **Starting a Session**
1. Launch DataDogs app
2. Tap **"New Session"**
3. Enter training details:
   - Handler name
   - Dog name/ID  
   - Training location
   - Session notes
4. Tap **"Start Recording"**

### **During Training**
- **Green indicator**: System actively analyzing behavior
- **Real-time metrics**: See live behavioral motifs detected
- **Synchrony score**: Handler-dog coordination (0-100%)
- **Session timer**: Track training duration

### **Ending a Session**
1. Tap **"Stop Recording"**
2. Wait for final analysis (15-30 seconds)
3. Review session summary:
   - Top 12 behavioral motifs detected
   - Handler-dog synchrony statistics
   - Session duration and highlights
4. Tap **"Save Session"** or **"Export Data"**

---

## 🎯 Understanding the Analysis

### **Behavioral Motifs (K=12)**
The system detects 12 key behaviors:
1. **Sit** - Dog sitting position
2. **Down** - Dog lying down
3. **Stay** - Maintaining position
4. **Come** - Recall movement
5. **Heel** - Walking beside handler
6. **Wait** - Paused attention
7. **Focus** - Eye contact/attention
8. **Turn** - Direction changes
9. **Stop** - Cessation of movement
10. **Alert** - Heightened attention
11. **Settle** - Relaxed positioning
12. **Transition** - Between-behavior movements

### **Synchrony Analysis**
- **Score Range**: 0-100%
- **>80%**: Excellent handler-dog coordination
- **60-80%**: Good coordination, room for improvement
- **<60%**: Consider reviewing training techniques
- **Lag Time**: How quickly dog responds to handler (milliseconds)

### **Confidence Scores**
- **>85%**: High confidence in behavior detection
- **70-85%**: Good detection, verify with observation
- **<70%**: Low confidence, may require review

---

## ⚙️ System Status Indicators

### **Router (GL-XE300)**
- **Blue LED**: Connected to LTE network (ready)
- **Red LED**: No LTE connection (check signal/SIM)
- **Flashing**: Connecting to network (wait 2-3 minutes)

### **Raspberry Pi**
- **Green LED**: System running normally
- **Red LED**: Power indicator
- **No LEDs**: Power issue or system failure

### **iPhone/iPad App Status**
- **🟢 Connected**: System ready for analysis
- **🟡 Connecting**: Establishing connection (normal on startup)
- **🔴 Offline**: Network issue - check WiFi connection

---

## 🔧 Troubleshooting

### **"Can't Connect to System"**
1. Check WiFi connection to `DataDogs-Field-[Location]`
2. Wait 4-5 minutes after powering on (system startup time)
3. Move closer to router (within 30 feet)
4. Restart iPhone WiFi (Settings → WiFi → Off/On)

### **"System Not Responding"**
1. Check router blue LED (should be solid blue)
2. Check Pi power LED (should be red)
3. Wait 2 minutes, then restart app
4. If problem persists, power cycle entire system

### **"Poor Signal Quality"**
1. Check LTE signal on router status page (192.168.8.1)
2. Move equipment to higher location or near windows
3. Check for interference from metal structures
4. Consider external antenna if consistently poor signal

### **"Analysis Results Seem Wrong"**
1. Ensure good lighting conditions
2. Keep handler and dog in camera view
3. Minimize background distractions
4. Check confidence scores in results (should be >70%)

### **"Battery Life Concerns"**
- **Router**: 6-8 hours continuous use
- **Raspberry Pi**: Requires continuous power (portable battery packs available)
- **iPhone/iPad**: Normal usage, consider portable charger for all-day sessions

---

## 📊 Data Management

### **Session Storage**
- Sessions automatically saved to device
- Cloud backup available (requires internet)
- Export options: PDF report, CSV data, video clips

### **Data Privacy**
- All analysis performed locally on Raspberry Pi
- No behavioral data transmitted to external servers
- Handler/dog information encrypted on device

### **Performance Optimization**
- **Ideal conditions**: Good lighting, minimal background motion
- **Camera positioning**: Keep handler and dog in frame
- **Session length**: 5-30 minutes optimal for analysis quality
- **Multiple dogs**: Analyze one handler-dog pair at a time

---

## 🚨 Emergency Procedures

### **Complete System Reset**
1. Power off router (unplug for 30 seconds)
2. Power off Raspberry Pi (hold power button 10 seconds)
3. Wait 1 minute
4. Power on router first, wait for blue LED
5. Power on Raspberry Pi
6. Wait 4-5 minutes for full startup

### **Contact Technical Support**
- **Email**: willflower2460@github.com
- **Include**: Photo of LED status, error messages, session details
- **Response time**: 24-48 hours
- **Emergency**: Call primary contact (provided separately)

---

## 📈 Getting the Most from Your System

### **Best Practices**
- **Consistent setup**: Use same camera angles and lighting when possible
- **Regular sessions**: System learns from repeated use
- **Review results**: Compare confidence scores across sessions
- **Document observations**: Note behaviors the system might miss

### **Training Integration**
- Use synchrony scores to identify timing improvements
- Focus on high-confidence motifs for reinforcement
- Track progress across multiple sessions
- Export data for training record keeping

### **System Care**
- Keep equipment dry and dust-free
- Store in protective case when not in use
- Charge batteries regularly
- Update iOS app when available

---

## 📋 Pre-Session Checklist

### ✅ **Equipment Ready**
- [ ] Router powered on with blue LED
- [ ] Pi powered on with red power LED
- [ ] iPhone/iPad charged and connected to WiFi
- [ ] DataDogs app updated and functioning
- [ ] Equipment positioned with clear view of training area

### ✅ **Environment Setup**
- [ ] Good lighting (natural light preferred)
- [ ] Minimal background distractions
- [ ] Clear sight lines to handler and dog
- [ ] Adequate WiFi coverage in training area

### ✅ **Session Planning**
- [ ] Handler and dog information ready
- [ ] Training objectives identified
- [ ] Session duration planned (5-30 minutes optimal)
- [ ] Data export method selected

---

## 🎓 Understanding Your Results

### **Session Summary Report**
- **Duration**: Total training time
- **Motifs Detected**: Count of each behavior type
- **Top Behaviors**: Most frequent 5 behaviors
- **Synchrony Average**: Overall coordination score
- **Confidence Score**: System certainty in analysis

### **Detailed Analytics**
- **Timeline View**: Behavior detection over session duration
- **Heatmap**: Most active training periods
- **Comparison**: Current vs previous session performance
- **Trends**: Improvement tracking over multiple sessions

### **Actionable Insights**
- Focus areas for next training session
- Behaviors to reinforce based on synchrony scores
- Timing improvements suggested by lag analysis
- Progress indicators compared to training goals

---

**System Version**: EdgeInfer v1.0  
**Last Updated**: August 28, 2025  
**Technical Support**: Repository available at https://github.com/wllmflower2460/pisrv_vapor_docker  
**User Manual Version**: 1.0