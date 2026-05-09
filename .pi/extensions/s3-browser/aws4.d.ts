declare module "aws4" {
  interface Aws4Request {
    host?: string;
    path?: string;
    method?: string;
    headers?: Record<string, string>;
    service?: string;
    region?: string;
    body?: string;
    signQuery?: boolean;
  }

  interface Aws4Credentials {
    accessKeyId: string;
    secretAccessKey: string;
    sessionToken?: string;
  }

  function sign(
    request: Aws4Request,
    credentials: Aws4Credentials,
  ): Aws4Request & {
    host: string;
    path: string;
    headers: Record<string, string>;
  };

  const aws4: { sign: typeof sign };
  export default aws4;
}
