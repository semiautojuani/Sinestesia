import processing.core.*;

// Clase que gestiona un grupo de partículas y su contenedor específico.
class ParticleSystem {
    PApplet p;
    Particle3D[] particles;
    PVector containerCenter;
    float containerSize;
    int particleShape;

    ParticleSystem(int numParticles, int shapeType, PVector center, float size, PApplet parent) {
        this.p = parent;
        this.containerCenter = center;
        this.containerSize = size;
        this.particleShape = shapeType;
        this.particles = new Particle3D[numParticles];
        
        initializeParticles(numParticles);
    }
    
    // Inicializa las partículas dentro de los límites del cubo asignado
    void initializeParticles(int numParticles) {
        float halfSize = containerSize / 2.0f;
        
        for (int i = 0; i < numParticles; i++) {
            // Posición inicial aleatoria dentro de los límites del cubo
            float startX = containerCenter.x + p.random(-halfSize, halfSize);
            float startY = containerCenter.y + p.random(-halfSize, halfSize);
            float startZ = containerCenter.z + p.random(-halfSize, halfSize);
            
            // Crea una nueva partícula con sus límites específicos
            this.particles[i] = new Particle3D(
                startX, startY, startZ,
                p.random(15, 30),
                i,
                this.particles, // Referencia al array de su propio sistema para colisión interna
                p,
                this.particleShape,
                this.containerCenter,
                this.containerSize
            );
        }
    }

    // Ejecuta la simulación y el renderizado para todo el sistema
    void run(PVector[] poseLandmarks, float landmarkRadius, float gravity, float friction, PVector mouse3D) {
        for (Particle3D particle : particles) {
            // Colisiones que afectan a la partícula
            if (poseLandmarks.length > 0) {
                particle.collideWithPose(poseLandmarks, landmarkRadius);
            }
            particle.collide(SPRING, particles.length); // Colisión entre partículas del mismo sistema
            particle.collideWithMouse(mouse3D);
            
            // Física, movimiento y colisión con el contenedor asignado
            particle.move(p, gravity, friction); 
            
            // Renderizar
            particle.display();
        }
    }
    
    // Reinicia las posiciones de las partículas dentro de su contenedor
    void reset() {
        float halfSize = containerSize / 2.0f;
        
        for (Particle3D particle : particles) {
            particle.x = containerCenter.x + p.random(-halfSize, halfSize);
            particle.y = containerCenter.y + p.random(-halfSize, halfSize);
            particle.z = containerCenter.z + p.random(-halfSize, halfSize);
            
            // Reiniciar velocidades
            particle.vx = 0;
            particle.vy = 0;
            particle.vz = 0;
        }
    }
}
