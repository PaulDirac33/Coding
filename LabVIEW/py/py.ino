unsigned long pretime = 0;
unsigned long time = 0;

void setup() {
  pretime = micros();
  Serial.begin(115200);
  time = micros();
  Serial.print("Setup completed in ");
  Serial.print(time - pretime);
  Serial.println(" µs");
}

void loop() {
  if (Serial.available()) {
    // Leggi la stringa inviata dalla seriale
    String input = Serial.readStringUntil('\n');
    Serial.println(input);
  //   char *tokens[6]; // Array per memorizzare i token
  //   char *token = strtok(const_cast<char *>(input.c_str()), " ");
  //   unsigned long numTokens = 0;
  //   while (token != NULL && numTokens < 6) {
  //     tokens[numTokens++] = token;
  //     token = strtok(NULL, " ");
  //   }
  //   dis = atoi(tokens[2]);
  //   par = atoi(tokens[3]);
  //   block = atoi(tokens[5]);
  //   if (block == 0){
  //     dt = 1000 * atoi(tokens[0]);
  //     T = 1000 * atoi(tokens[1]);
  //     t0 = dt + 1000*atoi(tokens[4]);
  //   }
  //   else if (block == 1){
  //     dt = 1000 * atoi(tokens[0]);
  //     T = 1000 * atoi(tokens[1]);
  //     t0 = T/2;
  //   }
   }
}
