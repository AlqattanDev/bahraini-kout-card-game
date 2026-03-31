import * as jose from "jose";

const ALG = "HS256";
const ISSUER = "bahraini-kout";
const EXPIRATION = "30d";

export async function signToken(uid: string, secret: string): Promise<string> {
  const key = new TextEncoder().encode(secret);
  return new jose.SignJWT({ uid })
    .setProtectedHeader({ alg: ALG })
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(EXPIRATION)
    .sign(key);
}

export async function verifyToken(token: string, secret: string): Promise<string> {
  const key = new TextEncoder().encode(secret);
  const { payload } = await jose.jwtVerify(token, key, { issuer: ISSUER });
  const uid = payload.uid;
  if (typeof uid !== "string") {
    throw new Error("Invalid token: missing uid");
  }
  return uid;
}
