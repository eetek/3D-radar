#include <Servo.h>

const int trigPin  = 10;
const int echoPin  = 11;
const int panPin   = 9;  // horizontal-sweep servo
const int tiltPin  = 12;  // vertical-sweep servo

Servo panServo;
Servo tiltServo;

// servo sweep ranges
const int panMin  = 15,  panMax  = 165;   // left/right
const int tiltMin = 30,  tiltMax = 90;    // down/up

const int panStep  = 3;   // bigger step = faster scan, lower horizontal resolution
const int tiltStep = 5;   // bigger step = fewer "rows", faster full-frame scan

long duration;
int  distance;
int  panAngle, tiltAngle;

void setup() {
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  Serial.begin(115200);       // faster baud since we're now sending 3x the data
  panServo.attach(panPin);
  tiltServo.attach(tiltPin);
}

void loop() {
  // sweep tilt from bottom to top, for each tilt "row" sweep pan across.
  // snap-back at the end of every row.
  for (tiltAngle = tiltMin; tiltAngle <= tiltMax; tiltAngle += tiltStep) {
    tiltServo.write(tiltAngle);
    delay(50);

    bool rowIsEven = (((tiltAngle - tiltMin) / tiltStep) % 2 == 0);

    if (rowIsEven) {
      for (panAngle = panMin; panAngle <= panMax; panAngle += panStep) {
        scanAndSend();
      }
    } else {
      for (panAngle = panMax; panAngle >= panMin; panAngle -= panStep) {
        scanAndSend();
      }
    }
  }
}

void scanAndSend() {
  panServo.write(panAngle);
  delay(25);
  distance = calculateDistance();

  Serial.print(panAngle);
  Serial.print(",");
  Serial.print(tiltAngle);
  Serial.print(",");
  Serial.print(distance);
  Serial.print(".");
}

int calculateDistance() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // timeout (~25ms ≈ 4m max range) so a missed echo doesn't freeze the sweep
  duration = pulseIn(echoPin, HIGH, 25000);
  int d = duration * 0.034 / 2;
  if (d == 0) d = 999; // no echo returned -> treat as "nothing in range"
  return d;
}
