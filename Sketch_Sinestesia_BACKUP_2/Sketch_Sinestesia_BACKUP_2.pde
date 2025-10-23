import oscP5.*; // Para recibir/enviar OSC
import netP5.*; // Dependencia de oscP5

// Variables de física
final float SPRING = 0.05f;
final float GRAVITY = 0.01f;
final float FRICTION = -0.9f;
final int NUM_BALLS = 100;
final float LANDMARK_RADIUS = 150.0f; // Usado en collideWithPose
final float HALF_DEPTH = 150.0f; // Usado como límite Z


// Variables globales
Ball3D[] balls = new Ball3D[NUM_BALLS];
PShape model3D = null; 
PVector[] poseLandmarks = new PVector[0];
PVector mouse3D = new PVector(0, 0, 0);

// Variables OSC/WebSocket
OscP5 oscP5;
NetAddress myRemoteLocation; 

final int OSC_RECEIVE_PORT = 12000; // Puerto donde Processing escucha
final int OSC_SEND_PORT = 12001; // Puerto al que Processing envía (ej. TouchDesigner)

void settings() {
    size(1280, 720, P3D); 
}

void setup() {
    colorMode(HSB, 360, 100, 100, 100);
    
    perspective();
    

    try {
        model3D = loadShape("3dAbril.obj");
        println("✓ Modelo 3D cargado");
    } catch (Exception e) {
        println("⚠ No se pudo cargar el modelo 3D, se usarán esferas: " + e.getMessage());
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
    
    // Inicializar conexión OSC
    initOSCConnection();

    println("✓ Simulación 3D iniciada");
    println("  Partículas: " + NUM_BALLS);
    println("  Canvas: " + width + "x" + height);
}

void draw() {
    background(0, 0); 
    
    // Configuración de la cámara / vista 3D
    translate(width / 2.0f, height / 2.0f, 0); // Centrar el origen (WEBGL-like)
    float currentZoomZ = -150; // Usamos esta variable para el zoom y el mouse
    translate(0, 0, currentZoomZ); 
    
    ambientLight(0f, 0f, 150f);
    directionalLight(255, 255, 255, 0.5f, 0.5f, -1);
    pointLight(255, 255, 255, 0, -200, 400);

    //MOUSE
    float mappedX = mouseX - width / 2.0f;
    float mappedY = mouseY - height / 2.0f;
    
    float interactionZ = 0.0f;

    mouse3D.set(mappedX, mappedY, interactionZ);
    // =========================================================

    pushMatrix(); 
    
    // CUBO
    stroke(255, 255, 255, 100); 
    strokeWeight(1); 
    noFill();
    
    box(width, height, HALF_DEPTH * 2); 

    popMatrix();


    // Simular partículas
    for (Ball3D ball : balls) {
        if (poseLandmarks.length > 0) {
            ball.collideWithPose(poseLandmarks, LANDMARK_RADIUS);
        }
        
        ball.collide(SPRING, NUM_BALLS);
        
        // LLAMADA NUEVA: Colisión con el Mouse (simula un pose/landmark)
        ball.collideWithMouse(this, mouse3D);
        
        ball.move(this, GRAVITY, FRICTION, HALF_DEPTH); 
        ball.display(model3D, HALF_DEPTH);
    }
    
    // Debug: dibujar landmarks
    if (poseLandmarks.length > 0) {
        drawLandmarks(poseLandmarks);
    }
    
    // Enviar datos a TouchDesigner (opcional)
    if (frameCount % 3 == 0) {
        sendParticleData();
    }
}
// ====================================================================
// El resto de funciones auxiliares (initOSCConnection, oscEvent, updateLandmarks, etc.)
// está correcto y se mantiene igual.
// ====================================================================
// ====================================================================
// Funciones de Lógica y OSC
// ====================================================================

// Inicializar conexión OSC (equivalente a initOSCConnection en JS)
void initOSCConnection() {
    // Inicializa el receptor OSC
    oscP5 = new OscP5(this, OSC_RECEIVE_PORT); 
    // Inicializa la dirección para enviar OSC (asumiendo localhost)
    myRemoteLocation = new NetAddress("127.0.0.1", OSC_SEND_PORT);
    
    println("✓ Escuchando mensajes OSC en puerto: " + OSC_RECEIVE_PORT);
}

// Método que OscP5 llama cuando llega un mensaje
void oscEvent(OscMessage theOscMessage) {
    // El formato del mensaje JS: { address: '/pose/landmarks', values: [...] }
    // En Java OSC, se usa el address (String) y los valores (varios tipos)
    
    String address = theOscMessage.addrPattern();
    
    // Manejar mensajes OSC de pose/hand tracking
    if (address.equals("/pose/landmarks") || address.equals("/hand/landmarks")) {
        // En p5.js, 'values' era un array de float (values: [Mano1_X, Mano2_X])
        if (theOscMessage.typetag().equals("ff")) { // Asegura que sean dos flotantes
            float val1 = theOscMessage.get(0).floatValue();
            float val2 = theOscMessage.get(1).floatValue();
            updateLandmarks(val1, val2);
        } else if (theOscMessage.typetag().equals("f")) {
            // Manejar un solo landmark si es necesario
            float val1 = theOscMessage.get(0).floatValue();
            updateLandmarks(val1, 0.5f); // Asumiendo que el segundo punto es fijo si solo viene uno
        }
    }
    
    // Reset de simulación
    if (address.equals("/simulation/reset")) {
        resetSimulation();
    }
    
    // Otros mensajes personalizados
    if (address.equals("/particles/gravity")) {
        // Aquí podrías cambiar la constante GRAVITY si fuera una variable no-final
    }
}

// Actualizar landmarks desde datos OSC (equivalente a updateLandmarks en JS)
void updateLandmarks(float val1, float val2) {
    // El mapeo de p5.js: -1 a 3 → 0 a 1
    // const normalize = (val) => (val + 1) / 4;
    
    poseLandmarks = new PVector[2]; // Redefine el array con 2 elementos
    
    // Normalizar de rango -1 a 3 → 0 a 1
    float norm1 = (val1 + 1.0f) / 4.0f;
    float norm2 = (val2 + 1.0f) / 4.0f;
    
    // Mapear coordenadas normalizadas (0-1) al espacio 3D de Processing
    float x1 = map(norm1, 0, 1, -width/2, width/2);
    float y1 = map(0.5f, 0, 1, -height/2, height/2); // Centro vertical (0.5f)
    float z1 = map(0.0f, -0.5f, 0.5f, -400, 400); // Centro profundidad (0.0f)

    float x2 = map(norm2, 0, 1, -width/2, width/2);
    float y2 = map(0.5f, 0, 1, -height/2, height/2); // Centro vertical (0.5f)
    float z2 = map(0.0f, -0.5f, 0.5f, -400, 400); // Centro profundidad (0.0f)

    // Mano 1
    poseLandmarks[0] = new PVector(x1, y1, z1);
    
    // Mano 2
    poseLandmarks[1] = new PVector(x2, y2, z2);
}

// Enviar datos de partículas a TouchDesigner (equivalente a sendParticleData en JS)
void sendParticleData() {
    // La versión p5.js enviaba un JSON con un array plano de 30 floats (x, y, z de 10 bolas)
    // Para enviar esto por OSC, usaremos un mensaje con una lista de flotantes.
    
    if (oscP5 == null) return;
    
    OscMessage msg = new OscMessage("/particles/positions");
    
    // Solo las primeras 10 partículas
    for (int i = 0; i < 10 && i < balls.length; i++) {
        PVector pos = balls[i].getPosition();
        msg.add(pos.x);
        msg.add(pos.y);
        msg.add(pos.z);
    }
    
    // Envía el mensaje OSC
    oscP5.send(msg, myRemoteLocation);
}

// Resetear simulación (equivalente a resetSimulation en JS)
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

// Dibujar landmarks (debug) (equivalente a drawLandmarks en JS)
void drawLandmarks(PVector[] landmarks) {
    pushMatrix();
    noStroke();
    
    for (int i = 0; i < landmarks.length; i++) {
        PVector lm = landmarks[i];
        
        pushMatrix();
        // Las coordenadas del PVector ya están mapeadas al espacio 3D
        translate(lm.x, lm.y, lm.z);
        
        // Color diferente para cada landmark
        fill((i * 20) % 360, 80, 100, 80);
        sphere(25);
        
        popMatrix();
    }
    
    popMatrix();
}

// Manejar teclas
void keyPressed() {
    if (key == 'r' || key == 'R') {
        resetSimulation();
    }
    
    // No hay funcionalidad integrada de UI/consola como en p5.js, pero puedes imprimir info:
    if (key == 'd' || key == 'D') {
        println("Debug info: Partículas=" + balls.length + ", Landmarks=" + poseLandmarks.length + ", FPS=" + round(frameRate));
    }
}

// Ajustar canvas al redimensionar (Processing no lo hace automáticamente en P3D/Java)
void windowResized() {
    // Esta función solo funciona si el sketch se está ejecutando en un PApplet no-fullscreen
    // resizeCanvas(windowWidth, windowHeight); // En p5.js
}
