import de.fhpotsdam.unfolding.mapdisplay.*;
import de.fhpotsdam.unfolding.utils.*;
import de.fhpotsdam.unfolding.marker.*;
import de.fhpotsdam.unfolding.tiles.*;
import de.fhpotsdam.unfolding.interactions.*;
import de.fhpotsdam.unfolding.ui.*;
import de.fhpotsdam.unfolding.*;
import de.fhpotsdam.unfolding.core.*;
import de.fhpotsdam.unfolding.mapdisplay.shaders.*;
import de.fhpotsdam.unfolding.data.*;
import de.fhpotsdam.unfolding.geo.*;
import de.fhpotsdam.unfolding.texture.*;
import de.fhpotsdam.unfolding.events.*;
import de.fhpotsdam.utils.*;
import de.fhpotsdam.unfolding.providers.*;

import java.io.*;
import java.text.*;
import java.util.*;
import java.util.regex.*;

// Key objects
ActiveSet as;
MdParser mc2p;
// Timing
long g_time = -1;
long step = 3600000 * 3;

int millisPrev;
// Controls
boolean parsed;
boolean paused;
boolean backwards;
boolean showVolumes = true;
boolean helpShown;
int hudMode = 1;

// How long do they linger?
long commLinger = 86400000 * 3; // 3 days
float charScale = 1;

PImage mapImg;

// Handy for display
String helpText =
  "Metadata Hyperliser Help\n\n" +
  "h - close Help\n" +
  "p - Pause or resume\n" +
  "f - Faster\n" +
  "s - Slower\n" +
  "b - Backwards or forwards\n" +
  "v - Volumes (active, past, future)\n" +
  "u - HUD mode (clock, etc)\n" + 
  "i - take Image (saves to file)\n" +
  "esc - exit";
DecimalFormat df1 = new DecimalFormat("0.0");
DecimalFormat df3 = new DecimalFormat("0.000");

UnfoldingMap map;

void setup() {
  size(640, 640);
  smooth();
  noCursor();
  ArrivalExitManager mgr = new ArrivalExitManager();
  HashMap<String, Integer> partyIds = new HashMap<String, Integer>();
  as = new ActiveSet(mgr);
  mc2p = new MdParser(mgr, partyIds);
  background(0);
  fill(255);
  textAlign(CENTER);
  text("Parsing metadata logs...", width / 2, height / 2 - 200);
  //drawHelp();
  mc2p.parseLines("sample-metadata.csv");
  mc2p.finishParse();
  parsed = true;
  
  map = new UnfoldingMap(this, new Google.GoogleTerrainProvider());
  map.setTweening(true);
  List<Location> locs = new ArrayList<Location>();
  locs.add(new Location(-32.5, 141));
  locs.add(new Location(-43.5, 155));
  map.zoomAndPanToFit(locs);
  
  //doPauseResume();
}

void draw() {
  if (!parsed) {
    millisPrev = millis();
    return;
  }
  background(0);
  
  noStroke();
  map.draw();
  fill(0, 128);
  rect(0, 0, width, height);
  
  as.updateAndDraw(g_time);
  int tDiff = millis() - millisPrev;
  float fps = (1000.0 / tDiff);
  if (hudMode > 0) {
    float speedFactor = step / 1000.0 * fps;
    drawClock(speedFactor);
  }
  if (showVolumes) {
    drawVolumes();  
  }
  g_time += (backwards ? -1 : 1) * step;
  if (hudMode > 1) {
    drawVizData(fps, step);
  }  
  millisPrev = millis();
}

void keyPressed() {
  if (key == 'p') {
    if (!helpShown) {
      doPauseResume();
    }
  }
  else if (key == 'f') {
    println("faster");
  }
  else if (key == 's') {
    println("slower");
  }
  else if (key == 'b') {
    backwards = !backwards;
  }
  else if (key == 'i') {
    saveFrame("metadata-######.png");
  }
  else if (key == 'u') {
    hudMode = (hudMode + 1) % 3;
  }
  else if (key == 'v') {
    showVolumes = !showVolumes;
  }
  else if (key == 'h') {
    if (!helpShown) {
      if (paused) return;
      drawHelp();
    }
    doPauseResume();
    helpShown = !helpShown;
  }
}



// Need to play more with this
// Maybe lingers should be constant
void updateLingers() {
}


void doPauseResume() {
  if (paused) {
    loop();
  }
  else {
    fill(color(#00ccff));
    textAlign(LEFT);
    pushMatrix();
    translate(width / 2, height - 50);
    scale(charScale);
    text("||", -5, 5);
    popMatrix();
    
    noLoop();
  }
  paused = !paused;
}

void drawClock(float speedFactor) {
  pushMatrix();
  translate(width -140, height - 40);
  scale(charScale);
  textAlign(LEFT);
  strokeWeight(2);
  stroke(color(#00ccff));
  fill(color(0,192,255,64));
  rect(-0, -15, 120, 30, 10, 10, 10, 10);
  fill(color(#00ccff));
  Date date = new Date(g_time);
  SimpleDateFormat sdf = new SimpleDateFormat("dd/MM/yy hh:mm");
  text(sdf.format(date), 15, 5);
  textAlign(RIGHT);
  //text((backwards ? "-" : "") + df1.format(speedFactor) + "x", -25, 5);
  popMatrix();
}

void drawVolumes() {
  float wd = 30;
  float ht = height - 200;
  int past = as.getAEManager().exitsSize();
  int nowPhone = 0;
  int nowSMS = 0;
  int nowInternet = 0;
  Iterator<Comm> it = as.getComms().iterator();
  while (it.hasNext()) {
    Comm comm = it.next();
    if (comm.type.equals("Phone")) {
      nowPhone++;
    }
    else if (comm.type.equals("SMS")) {
      nowSMS++;
    }
    else if (comm.type.equals("Internet")) {
      nowInternet++;
    }
  }
  int now = nowPhone + nowSMS + nowInternet;
  int future = as.getAEManager().arrivalsSize();
  int total = past + now + future;
  float htF = ht / total;
  float x0 = width - 120;
  float y0 = 100;
  strokeWeight(2);
  stroke(128);
  fill(255,32);
  rect(x0 - 20, y0 - 20, wd + 90, ht + 40, 20, 20, 20, 20);
  rect(x0, y0, wd, past * htF, 10, 10, 0, 0);
  rect(x0, y0 + (past + now) * htF, wd, future * htF, 0, 0, 10, 10);
  textAlign(LEFT);
  fill(192);
  if (past * htF > 30) {
    text(past,
      x0 + wd + 10, y0 + past * htF / 2 + 5);
  }
  if (future * htF > 30) {
    text(future,
      x0 + wd + 10, y0 + (past + now + future / 2.0) * htF + 5);
  }
  // Now stuff
  //fill(255,128);
  if (nowPhone > 0) {
    stroke(255, 209, 13);
    fill(255, 209, 13, 128);
    rect(x0 - 5, y0 + past * htF, wd + 10, nowPhone * htF, 5, 5, 5, 5);
  }
  if (nowSMS > 0) {
    stroke(20, 204, 108);
    fill(20, 204, 108, 128);
    rect(x0 - 5, y0 + past * htF + nowPhone * htF, wd + 10, nowSMS * htF, 5, 5, 5, 5);
  }
  if (nowInternet > 0) {
    stroke(255, 0, 255, 128);
    fill(255, 0, 255, 128);
    rect(x0 - 5, y0 + past * htF + (nowPhone + nowSMS) * htF, wd + 10, nowInternet * htF, 5, 5, 5, 5);
  }
  fill(255);
  text(now, x0 + wd + 10, y0 + (past + now / 2.0) * htF + 5);
}


void drawVizData(float fps, float step) {
  textAlign(LEFT);
  fill(96);
  text("step " + df3.format(step), 70, 20);
  text("fps " + ((int) fps), 20, 20);
}

void drawHelp() {
  float rectW = 250;
  float rectH = 250;
  fill(218,0,85,64);
  stroke(218,0,85);
  rect((width - rectW) / 2, (height - rectH) / 2, rectW, rectH,
    20, 20, 20, 20);
  fill(218,0,85);
  textAlign(LEFT);
  text(helpText, (width - rectW) / 2 + 20, (height - rectH) / 2 + 20,
    (width + rectW) / 2 - 20, (height + rectH) / 2 - 20);
}

class ActiveSet {
  Set<Comm> comms;
  ArrivalExitManager mgr;
  
  ActiveSet(ArrivalExitManager mgr) {
    comms = new HashSet<Comm>();
    this.mgr = mgr;
  }
  
  ArrivalExitManager getAEManager() {
    return mgr;
  }
  
  void addActive(Comm comm) {
    comms.add(comm);
  }
  
  Set<Comm> getComms() {
    return comms;
  }
  
  int size() {
    return comms.size();
  }
  
  void updateAndDraw(long time) {
    if (backwards) {
      mgr.popExits(this, time);
    }
    else {
      mgr.popArrivals(this, time);
    } 
    Iterator<Comm> it = comms.iterator();
    while (it.hasNext()) {
      Comm c = it.next();
      if (backwards) {
        if (!c.isInspired(time)) {
          mgr.notifyArrival(c);
          it.remove();
        }
      }
      else {
        if (c.isExpired(time)) {
          mgr.notifyExit(c);
          it.remove();
        }
      }
      c.update(time);
      c.draw();
    }
    if (backwards) {
      mgr.commitArrivals();
    }
    else {
      mgr.commitExits();
    }
  }
}

// Note we could probably save half this code by being smarter with backwards
class ArrivalExitManager {
  Stack<Comm> arrivals;
  Stack<Comm> exits;

  // Sorted collections with comparators may also save code  
  ArrayList<Comm> notifiedArrivals;
  ArrayList<Comm> notifiedExits;

  ArrivalExitManager() {
    arrivals = new Stack<Comm>();
    exits = new Stack<Comm>();
    
    notifiedArrivals = new ArrayList<Comm>();
    notifiedExits = new ArrayList<Comm>();
  }
  
  // Push Comm directly to arrivals
  void pushArrival(Comm arrival) {
    arrivals.push(arrival);
  }
  
  // Notify of a Comm to be pushed in the next commit
  void notifyArrival(Comm arrival) {
    if (notifiedArrivals.size() == 0) {
      notifiedArrivals.add(arrival);
    }
    else {
      int i = 0;
      while (notifiedArrivals.get(i).timeInspired() < arrival.timeInspired()) {
        i++;
        if (i > notifiedArrivals.size() - 1) break;
      }
      notifiedArrivals.add(i, arrival);
    }
  }
  
  // Commit all notified Comms since the last commit
  // The arrival set will be pushed in reverse time order of arrival
  // (NB. time order not guaranteed when iterating ActiveSet)
  void commitArrivals() {
    for (int i = notifiedArrivals.size() - 1; i >= 0; i--) {
      arrivals.push(notifiedArrivals.get(i));
    }
    notifiedArrivals.clear();
  }
  
  void notifyExit(Comm exit) {
    if (notifiedExits.size() == 0) {
      notifiedExits.add(exit);
    }
    else {
      int i = 0;
      while (notifiedExits.get(i).timeExpired() < exit.timeExpired()) {
        i++;
        if (i > notifiedExits.size() - 1) break;
      }
      notifiedExits.add(i, exit);
    }
  }
  
  // The exit set will be pushed in time order of exit
  void commitExits() {
    for (int i = 0; i < notifiedExits.size(); i++) {
      exits.push(notifiedExits.get(i));
    }
    notifiedExits.clear();
  } 
  
  void popArrivals(ActiveSet as, long time) {
    if (arrivals.size() == 0) return;
    Comm arrival = arrivals.peek();
    while(arrival.isInspired(time)) {
      arrivals.pop();
      as.addActive(arrival);
      if (arrivals.size() == 0) break;
      arrival = arrivals.peek();
    }
  }
  
  void popExits(ActiveSet as, long time) {
    if (exits.size() == 0) return;
    Comm exit = exits.peek();
    while(!exit.isExpired(time)) {
      exits.pop();
      as.addActive(exit);
      if (exits.size() == 0) break;
      exit = exits.peek();
    }  
  }
  
  int arrivalsSize() {
    return arrivals.size();
  }
  
  int exitsSize() {
    return exits.size();
  }
  
}

class Comm implements Comparable<Comm> {
  
  // Comm properties
  int id;
  String type;
  String partyId;
  Date dateTime;
  String towerLoc;
  float towerLat;
  float towerLng;
  Location mapLoc;
  
  // Derived
  color c0, c1;
  long linger;
  float rad;
  float thick;
  
  // Dynamic
  float progress;
  
  Comm(int id, String type, String partyId, Date dateTime,
    String towerLoc, float lat, float lng) {
    this.id = id;
    this.type = type;
    this.partyId = partyId;
    this.dateTime = dateTime;
    this.towerLoc = towerLoc;
    this.towerLat = lat;
    this.towerLng = lng;
    mapLoc = new Location(towerLat, towerLng);
    
    if (type.equals("Phone")) {
      c0 = color(255, 209, 13, 128);
      c1 = color(255, 209, 13, 0);
      linger = commLinger * 4;
      rad = 40;
      thick = 4;
    }
    else if (type.equals("SMS")) {
      c0 = color(20, 204, 108, 128);
      c1 = color(20, 204, 108, 0);
      linger = commLinger;
      rad = 40;
      thick = 4;
    }
    else if (type.equals("Internet")) {
      c0 = color(255, 0, 255, 128);
      c1 = color(255, 0, 255, 0);
      linger = commLinger * 2;
      rad = 15;
      thick = 1;
    }
    else {
      c0 = color(0, 0);
      c1 = color(0, 0);
      linger = 0;
      rad = 0;
    }
  }
     
  // Determines state and transitions at specified time
  void update(long time) {
    long delta = time - dateTime.getTime();
    progress = constrain(delta / (linger * 1.0), 0.01, 0.99);
  }
      
  // This draws the Comm
  // given the state, progress & transitions calculated by update
  void draw() {
    ScreenPosition screen = map.getScreenPosition(mapLoc);
    
    color col = lerpColor(c0, c1, progress);
    noFill();
    strokeWeight(thick);
    stroke(col);
    
    ellipse(screen.x, screen.y,
      10 + rad * progress, 10 + rad * progress);
  }    
    

  String getType() {
    return type;
  }
      
  long timeInspired() {
    return dateTime.getTime();
  }
  
  boolean isInspired(long time) {
    return time > timeInspired();
  }

  float timeExpired() {
    return timeInspired() + linger;
  }

  boolean isExpired(long time) {
    return time > timeExpired();
  }

  int compareTo(Comm o) {
    long delta = this.dateTime.getTime() - o.dateTime.getTime();
    return (int) Math.signum(delta);
  }
}

class MdParser {
  // tokens & constants in log
  int TOKEN_ID = 0;
  int TOKEN_COMM_TYPE = 1;
  int TOKEN_PARTY_ID = 2;
  int TOKEN_COMM_DATE = 3;
  int TOKEN_COMM_TIME = 4;
  int TOKEN_COMM_TIMEDATE = 5;
  int TOKEN_COMM_TWR_LOC = 7;
  int TOKEN_COMM_TWR_LAT = 8;
  int TOKEN_COMM_TWR_LNG = 9;
  
  ArrivalExitManager mgr;
  ArrayList<Comm> arrivals;
  HashMap<String, Integer> partyIds;
  int numParties;

  MdParser(ArrivalExitManager mgr, HashMap<String, Integer> partyIds) {
    this.mgr = mgr;
    this.partyIds = partyIds;
    arrivals = new ArrayList<Comm>();
  }
  
  void parseLines(String fname) {
    String[] loglines = loadStrings(fname);
    for (int i = 1; i < loglines.length; i++) {
      String[] tokens = split(loglines[i], ',');
      int id = Integer.parseInt(tokens[TOKEN_ID]);
      String type = tokens[TOKEN_COMM_TYPE];
      String partyId = tokens[TOKEN_PARTY_ID];
      
      // Tally communication parties
      Integer partyCount = new Integer(1);
      if (partyIds.keySet().contains(partyId)) {
        int currCount = partyIds.get(partyId).intValue();
        partyCount = new Integer(currCount++);
      }
      partyIds.put(partyId, partyCount);
      
      SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
      Date date = new Date(0);
      try {
        date = sdf.parse(tokens[TOKEN_COMM_TIMEDATE]);
        if (g_time == -1) {
          g_time = date.getTime();
        }
      }
      catch (ParseException e) {
        println("Date format error: " + e);
      }

      String towerLoc = tokens[TOKEN_COMM_TWR_LOC];
      float lat = 0.0;
      float lng = 0.0;
      try {
        lat = Float.parseFloat(tokens[TOKEN_COMM_TWR_LAT]);
        lng = Float.parseFloat(tokens[TOKEN_COMM_TWR_LNG]);
      }
      catch (NumberFormatException e) {
        println("Lat/lng format error");
      }
      Comm newComm = new Comm(id, type, partyId, date, towerLoc, lat, lng);
      arrivals.add(newComm);
    }
  }
  
  void finishParse() {
    Collections.sort(arrivals);
    // Here we should assign a rank to each partyId
    for (int i = arrivals.size() - 1; i >= 0; i--) {
      // We might want to do more aggregate stuff here
      Comm comm = arrivals.get(i);
      mgr.pushArrival(comm);
    }
  }  
      
}


// todo - this is only for a max 24hrs
float getSeconds(String arrivalTimeString) {
  String[] tokens = split(arrivalTimeString, ":");
  try {
    float hours = Float.parseFloat(tokens[0]);
    float minutes = Float.parseFloat(tokens[1]);
    float seconds = Float.parseFloat(tokens[2]);
    return seconds + 60 * (minutes + 60 * (hours));
  }
  catch (NumberFormatException e) {
    println("Arrival time format error");
    return 0;
  }
}

String hhMmSs(int seconds) {
  int secondsThisDay = abs(seconds) % 86400;
  int hh = secondsThisDay / 3600;
  int hhR = secondsThisDay % 3600;
  int mm = hhR / 60;
  int ss = hhR % 60;
  return (seconds < 0 ? "-" : "")
    + (hh < 10 ? "0" : "") + hh + ":"
    + (mm < 10 ? "0" : "") + mm + ":"
    + (ss < 10 ? "0" : "") + ss;
}

String plusDays(int seconds) {
  int days = seconds / 86400;
  return (days < 1) ? "" : "+" + seconds / 86400;
}

String truncateString(String str, int length) {
   return (str.length() > length ? str.substring(0, length) + "..." : str);
}

