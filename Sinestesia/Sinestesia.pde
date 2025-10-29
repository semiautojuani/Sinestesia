import oscP5.*;
import netP5.*;

// Variables de física
final float SPRING = 0.05f;
final float GRAVITY = 0.01f;
final float FRICTION = -0.9f;
final int NUM_BALLS = 100;
final float LANDMARK_RADIUS = 150.0f;
final float HALF_DEPTH = 150.0f;

// Variables globales
Ball3D[] balls = new Ball3D[NUM_BALLS];
PShape model3D = null; 
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
    
    // Cargar modelo 3D
    try {
        model3D = loadShape("3dAbril.obj");
        println("✓ Modelo 3D cargado: 3dAbril.obj");
    } catch (Exception e) {
        println("⚠ No se pudo cargar el modelo 3D, usando esferas");
        println("  Error: " + e.getMessage());
    }
    
    // Inicializar partículas
    for (int i = 0; i < NUM_BALLS; i++) {
        balls[i] = new Ball3D(
            random(-width/2, width/2),
            random(-height/2, height/2),
            random(-HALF_DEPTH, HALF_DEPTH),
            random(15, 30),
            i,
            balls,
            this
        );
    }
    
    // Inicializar OSC
    initOSCConnection();

    println("✓ Simulación 3D iniciada");
    println("  Partículas: " + NUM_BALLS);
    println("  Canvas: " + width + "x" + height);
    println("  Puerto OSC escucha: " + OSC_RECEIVE_PORT);
    println("  Puerto OSC envío: " + OSC_SEND_PORT);
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

    // Dibujar cubo contenedor
    pushMatrix(); 
    stroke(255, 255, 255, 100); 
    strokeWeight(1); 
    noFill();
    box(width, height, HALF_DEPTH * 2); 
    popMatrix();

    // Simular y renderizar partículas
    for (Ball3D ball : balls) {
        // Colisión con landmarks de pose
        if (poseLandmarks.length > 0) {
            ball.collideWithPose(poseLandmarks, LANDMARK_RADIUS);
        }
        
        // Colisión entre partículas
        ball.collide(SPRING, NUM_BALLS);
        
        // Colisión con mouse
        ball.collideWithMouse(mouse3D);
        
        // Física y movimiento
        ball.move(this, GRAVITY, FRICTION, HALF_DEPTH); 
        
        // Renderizar
        ball.display(model3D, HALF_DEPTH);
    }
    
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
    } catch (Exception e) {
        println("✗ Error al inicializar OSC: " + e.getMessage());
    }
}

// Recibir mensajes OSC
void oscEvent(OscMessage theOscMessage) {
    String address = theOscMessage.addrPattern();
    
    try {
        // Recibir landmarks de pose/hand desde TouchDesigner
        if (address.equals("/pose/landmarks") || address.equals("/hand/landmarks")) {
            if (theOscMessage.typetag().equals("ff")) {
                float val1 = theOscMessage.get(0).floatValue();
                float val2 = theOscMessage.get(1).floatValue();
                updateLandmarks(val1, val2);
            } else if (theOscMessage.typetag().equals("f")) {
                float val1 = theOscMessage.get(0).floatValue();
                updateLandmarks(val1, 0.5f);
            }
        }
        
        // Reset de simulación
        if (address.equals("/simulation/reset")) {
            resetSimulation();
        }
        
        // Control de gravedad (ejemplo adicional)
        if (address.equals("/particles/gravity")) {
            // float newGravity = theOscMessage.get(0).floatValue();
            // GRAVITY = newGravity; // Requeriría que GRAVITY no sea final
        }
    } catch (Exception e) {
        println("✗ Error procesando mensaje OSC: " + address);
        println("  " + e.getMessage());
    }
}

// Actualizar landmarks desde datos OSC
void updateLandmarks(float val1, float val2) {
    poseLandmarks = new PVector[2];
    
    // Normalizar de rango [-1, 3] a [0, 1]
    float norm1 = (val1 + 1.0f) / 4.0f;
    float norm2 = (val2 + 1.0f) / 4.0f;
    
    // Mapear a espacio 3D
    float x1 = map(norm1, 0, 1, -width/2, width/2);
    float y1 = 0; // Centro vertical
    float z1 = 0; // Centro de profundidad

    float x2 = map(norm2, 0, 1, -width/2, width/2);
    float y2 = 0;
    float z2 = 0;

    poseLandmarks[0] = new PVector(x1, y1, z1);
    poseLandmarks[1] = new PVector(x2, y2, z2);
}

// Enviar posiciones de partículas a TouchDesigner
void sendParticleData() {
    if (oscP5 == null || myRemoteLocation == null) {
        return;
    }
    
    try {
        OscMessage msg = new OscMessage("/particles/positions");
        
        // Enviar primeras 10 partículas (ajusta según necesidad)
        int particlesToSend = min(10, balls.length);
        
        for (int i = 0; i < particlesToSend; i++) {
            PVector pos = balls[i].getPosition();
            msg.add(pos.x);
            msg.add(pos.y);
            msg.add(pos.z);
        }
        
        oscP5.send(msg, myRemoteLocation);
    } catch (Exception e) {
        println("✗ Error enviando datos OSC: " + e.getMessage());
    }
}

// Resetear simulación
void resetSimulation() {
    for (Ball3D ball : balls) {
        ball.x = random(-width/2, width/2);
        ball.y = random(-height/2, height/2);
        ball.z = random(-HALF_DEPTH, HALF_DEPTH);
        ball.vx = 0;
        ball.vy = 0;
        ball.vz = 0;
    }
    println("↻ Simulación reseteada");
}

// Dibujar landmarks (debug)
void drawLandmarks(PVector[] landmarks) {
    pushMatrix();
    noStroke();
    
    for (int i = 0; i < landmarks.length; i++) {
        PVector lm = landmarks[i];
        
        pushMatrix();
        translate(lm.x, lm.y, lm.z);
        
        // Color diferente por landmark
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
        println("  Partículas: " + balls.length);
        println("  Landmarks: " + poseLandmarks.length);
        println("  FPS: " + round(frameRate));
        println("  Mouse 3D: (" + mouse3D.x + ", " + mouse3D.y + ", " + mouse3D.z + ")");
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
