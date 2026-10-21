const fastify = require('fastify')({ logger: true });

const PORT = process.env.PORT || 3000;

// Root endpoint
fastify.get('/', async (request, reply) => {
    return { message: 'Server is running smoothly!' };
});

// Health check endpoint (Pure Fastify return syntax)
fastify.get('/health', async (request, reply) => {
    return { status: 'ok', region: process.env.AWS_REGION_NAME || 'unknown' };
});

// Start server
const start = async () => {
    try {
        await fastify.listen({ port: parseInt(PORT), host: '0.0.0.0' });
    } catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
};

// Graceful shutdown handling
process.on('SIGTERM', async () => {
    fastify.log.info('SIGTERM signal received: closing Fastify server');
    await fastify.close();
    fastify.log.info('Fastify server closed');
    process.exit(0);
});

start();