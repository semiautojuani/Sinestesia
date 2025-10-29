import oscP5.*;
import netP5.*;
import java.util.Arrays; // Necesario para algunas operaciones de array si se usaran, aunque no en este caso.

// Variables de física
final float SPRING = 0.05f;
final float GRAVITY = 0.01f;
final float FRICTION = -0.9f;
final float LANDMARK_RADIUS = 150.0f; // Radio de interacción de los landmarks

// CONSTANTES DE CUBO Y PARTICULAS
final float CUBE_SIZE = 300.0f; // Lado de 200x200x200
final int PARTICLES_PER_SYSTEM = 50;

// POSICIONES CENTRALES DE LOS CUBOS EN ESPACIO 3D (separados horizontalmente)
final PVector CUBE_1_CENTER = new PVector(-400, 0, 0); // Izquierda
final PVector CUBE_2_CENTER = new PVector(0, 0, 0);    // Centro
final PVector CUBE_3_CENTER = new PVector(400, 0, 0);   // Derecha

// Sistemas de partículas (tres grupos distintos)
ParticleSystem system1; // Ejemplo: Pirámides
ParticleSystem system2; // Ejemplo: Cubos
ParticleSystem system3; // Ejemplo: Esferas

// Variables globales restantes
PVector[] poseLandmarks = new PVector[0];
PVector mouse3D = new PVector(0, 0, 0);

// Variables OSC
OscP5 oscP5;
NetAddress myRemoteLocation;

final int OSC_RECEIVE_PORT = 12000; // Puerto de escucha
final int OSC_SEND_PORT = 12001;    // Puerto de envío a TD

void settings() {
  size(1280, 720, P3D);
}

void setup() {
  colorMode(HSB, 360, 100, 100, 100);
  perspective();

  // NOTA: Se ha eliminado la carga de model3D (3dAbril.obj) ya que usaremos formas primitivas.

  // Inicializar los 3 sistemas de partículas
  // Cada sistema recibe su tipo de forma y su contenedor
  system1 = new ParticleSystem(
    PARTICLES_PER_SYSTEM,
    Particle3D.SHAPE_PYRAMID,
    CUBE_1_CENTER,
    CUBE_SIZE,
    this
    );
  system2 = new ParticleSystem(
    PARTICLES_PER_SYSTEM,
    Particle3D.SHAPE_CUBE,
    CUBE_2_CENTER,
    CUBE_SIZE,
    this
    );
  system3 = new ParticleSystem(
    PARTICLES_PER_SYSTEM,
    Particle3D.SHAPE_SPHERE,
    CUBE_3_CENTER,
    CUBE_SIZE,
    this
    );

  // Inicializar OSC
  initOSCConnection();

  println("✓ Simulación 3D iniciada con 3 contenedores");
  println("  Partículas por sistema: " + PARTICLES_PER_SYSTEM);
}

void draw() {
  background(0, 0, 0);

  // Configurar cámara 3D
  translate(width / 2.0f, height / 2.0f, 0);
  float cameraZoom = -150;
  translate(0, 0, cameraZoom);

  // Iluminación
  ambientLight(0, 0, 150);
  directionalLight(255, 255, 255, 0.5f, 0.5f, -1);
  pointLight(255, 255, 255, 0, -200, 400);

  // Actualizar posición del mouse en espacio 3D
  float mappedX = mouseX - width / 2.0f;
  float mappedY = mouseY - height / 2.0f;
  mouse3D.set(mappedX, mappedY, 0);

  // --- DIBUJAR CUBOS CONTENEDORES ---
  stroke(255, 255, 255, 100);
  strokeWeight(1);
  noFill();

  // Dibujar Cubo 1 (Pirámides)
  pushMatrix();
  translate(CUBE_1_CENTER.x, CUBE_1_CENTER.y, CUBE_1_CENTER.z);
  box(CUBE_SIZE);
  popMatrix();

  // Dibujar Cubo 2 (Cubos)
  pushMatrix();
  translate(CUBE_2_CENTER.x, CUBE_2_CENTER.y, CUBE_2_CENTER.z);
  box(CUBE_SIZE);
  popMatrix();

  // Dibujar Cubo 3 (Esferas)
  pushMatrix();
  translate(CUBE_3_CENTER.x, CUBE_3_CENTER.y, CUBE_3_CENTER.z);
  box(CUBE_SIZE);
  popMatrix();

  // --- SIMULAR Y RENDERIZAR SISTEMAS ---
  system1.run(poseLandmarks, LANDMARK_RADIUS, GRAVITY, FRICTION, mouse3D);
  system2.run(poseLandmarks, LANDMARK_RADIUS, GRAVITY, FRICTION, mouse3D);
  system3.run(poseLandmarks, LANDMARK_RADIUS, GRAVITY, FRICTION, mouse3D);

  // Debug: dibujar landmarks
  if (poseLandmarks.length > 0) {
    drawLandmarks(poseLandmarks);
  }

  // Enviar datos a TouchDesigner cada 3 frames
  if (frameCount % 3 == 0) {
    sendParticleData();
  }
}

// ====================================================================
// FUNCIONES OSC
// ====================================================================

void initOSCConnection() {
  try {
    oscP5 = new OscP5(this, OSC_RECEIVE_PORT);
    myRemoteLocation = new NetAddress("127.0.0.1", OSC_SEND_PORT);
    println("✓ OSC inicializado correctamente");
  }
  catch (Exception e) {
    println("✗ Error al inicializar OSC: " + e.getMessage());
  }
}

// Recibir mensajes OSC (sin cambios)
void oscEvent(OscMessage theOscMessage) {
  String address = theOscMessage.addrPattern();

  try {
    if (address.equals("/pose/landmarks") || address.equals("/hand/landmarks")) {
      // ... (lógica de landmarks)
    }

    if (address.equals("/simulation/reset")) {
      resetSimulation();
    }
  }
  catch (Exception e) {
    println("✗ Error procesando mensaje OSC: " + address);
    println("  " + e.getMessage());
  }
}

// Actualizar landmarks desde datos OSC (sin cambios)
void updateLandmarks(float val1, float val2) {
  poseLandmarks = new PVector[2];

  // Normalizar de rango [-1, 3] a [0, 1]
  float norm1 = (val1 + 1.0f) / 4.0f;
  float norm2 = (val2 + 1.0f) / 4.0f;

  // Mapear a espacio 3D (ajustado al rango de los 3 cubos)
  float x1 = map(norm1, 0, 1, -width/2, width/2);
  float y1 = 0;
  float z1 = 0;

  float x2 = map(norm2, 0, 1, -width/2, width/2);
  float y2 = 0;
  float z2 = 0;

  poseLandmarks[0] = new PVector(x1, y1, z1);
  poseLandmarks[1] = new PVector(x2, y2, z2);
}

// Enviar posiciones de partículas a TouchDesigner (Actualizado)
void sendParticleData() {
  if (oscP5 == null || myRemoteLocation == null) {
    return;
  }

  int particlesToSend = 15; // Ajusta cuántas posiciones enviar por sistema

  // Enviar datos para el Sistema 1: Pirámides
  // Dirección OSC clara para TD: /particles/pyramids/pos
  sendSystemPositions(system1.particles, "/particles/pyramids/pos", min(particlesToSend, system1.particles.length));

  // Enviar datos para el Sistema 2: Cubos
  // Dirección OSC clara para TD: /particles/cubes/pos
  sendSystemPositions(system2.particles, "/particles/cubes/pos", min(particlesToSend, system2.particles.length));

  // Enviar datos para el Sistema 3: Esferas
  // Dirección OSC clara para TD: /particles/spheres/pos
  sendSystemPositions(system3.particles, "/particles/spheres/pos", min(particlesToSend, system3.particles.length));

  // Enviar las posiciones de los cubos (para que TD sepa dónde están)
  sendContainerPositions();
}

// Nueva función de utilidad para enviar un conjunto de partículas
void sendSystemPositions(Particle3D[] particles, String address, int count) {
  OscMessage msg = new OscMessage(address);

  for (int i = 0; i < count; i++) {
    PVector pos = particles[i].getPosition();
    // Envía la posición global de cada partícula
    msg.add(pos.x);
    msg.add(pos.y);
    msg.add(pos.z);
  }

  oscP5.send(msg, myRemoteLocation);
}

// Nueva función para enviar las posiciones centrales de los contenedores
void sendContainerPositions() {
  OscMessage msg = new OscMessage("/containers/centers");
  msg.add(CUBE_SIZE); // Incluye el tamaño del cubo para que TD pueda recrearlo

  msg.add(CUBE_1_CENTER.x).add(CUBE_1_CENTER.y).add(CUBE_1_CENTER.z);
  msg.add(CUBE_2_CENTER.x).add(CUBE_2_CENTER.y).add(CUBE_2_CENTER.z);
  msg.add(CUBE_3_CENTER.x).add(CUBE_3_CENTER.y).add(CUBE_3_CENTER.z);

  oscP5.send(msg, myRemoteLocation);
}

// Resetear simulación (Actualizado)
void resetSimulation() {
  system1.reset();
  system2.reset();
  system3.reset();
  println("↻ Simulación reseteada");
}

// Dibujar landmarks (debug) (sin cambios)
void drawLandmarks(PVector[] landmarks) {
  pushMatrix();
  noStroke();

  for (int i = 0; i < landmarks.length; i++) {
    PVector lm = landmarks[i];

    pushMatrix();
    translate(lm.x, lm.y, lm.z);

    fill((i * 180) % 360, 80, 100, 80);
    sphere(25);

    popMatrix();
  }

  popMatrix();
}

// ====================================================================
// CONTROLES
// ====================================================================

void keyPressed() {
  if (key == 'r' || key == 'R') {
    resetSimulation();
  }

  if (key == 'd' || key == 'D') {
    println("═══════════════════════════════════");
    println("DEBUG INFO:");
    println("  Sistemas Activos: 3");
    println("  Partículas totales: " + (PARTICLES_PER_SYSTEM * 3));
    println("  FPS: " + round(frameRate));
    println("═══════════════════════════════════");
  }

  if (key == 'h' || key == 'H') {
    println("═══════════════════════════════════");
    println("CONTROLES:");
    println("  R - Resetear simulación");
    println("  D - Mostrar debug info");
    println("  H - Mostrar ayuda");
    println("═══════════════════════════════════");
  }
}
