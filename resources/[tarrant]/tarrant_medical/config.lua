TarrantMedical = {
    recoverySeconds = 30,
    requestTimeout = 20,
    -- UNACCEPTED: live hospital recovery rejects this with ground_z_mismatch.
    -- No verified exterior replacement yet. Never substitute underground Z.
    -- Follow docs/medical-hospital-recovery.md to measure and remotely validate
    -- a replacement; runtime validation remains mandatory before any placement.
    hospital = { x = 300.8, y = -585.6, z = 43.28, heading = 70.0 },
    arrivalRadius = 5.0,
    collisionTimeoutMs = 8000,
}
