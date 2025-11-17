using Newtonsoft.Json;
using System;
using System.Net;
using System.IO;
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using Org.BouncyCastle.X509;
using Org.BouncyCastle.Utilities;
using Org.BouncyCastle.Math;
using Org.BouncyCastle.Security;
using Org.BouncyCastle.Asn1.X509;
using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.Crypto.Generators;
using Org.BouncyCastle.Crypto.Operators;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.Pkcs;
using System.Collections;
using Org.BouncyCastle.Asn1;
using System.Security.Cryptography;
using System.Net.Http;
using System.Text;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using System.Threading;
using Org.BouncyCastle.OpenSsl;

namespace certificategenerator
{
    class Program
    {

        internal static class Constants
        {
            /// <summary>
            /// constants related to masking the secrets in container environment variable
            /// </summary>
            public const string DEFAULT_LOG_ANALYTICS_WORKSPACE_DOMAIN = "opinsights.azure.com";

            public const string DEFAULT_SIGNATURE_ALOGIRTHM = "SHA256WithRSA";
        }

        private static X509Certificate2 CreateSelfSignedCertificate(string agentGuid, string logAnalyticsWorkspaceId)
        {
            var random = new SecureRandom();

            var certificateGenerator = new X509V3CertificateGenerator();

            var serialNumber = BigIntegers.CreateRandomInRange(BigInteger.One, BigInteger.ValueOf(Int64.MaxValue), random);

            certificateGenerator.SetSerialNumber(serialNumber);

            var dirName = string.Format("CN={0}, CN={1}, OU=Microsoft Monitoring Agent, O=Microsoft", logAnalyticsWorkspaceId, agentGuid);

            X509Name certName = new X509Name(dirName);

            certificateGenerator.SetIssuerDN(certName);

            certificateGenerator.SetSubjectDN(certName);

            certificateGenerator.SetNotBefore(DateTime.UtcNow.Date);

            certificateGenerator.SetNotAfter(DateTime.UtcNow.Date.AddYears(1));

            const int strength = 2048;

            var keyGenerationParameters = new KeyGenerationParameters(random, strength);

            var keyPairGenerator = new RsaKeyPairGenerator();

            keyPairGenerator.Init(keyGenerationParameters);

            var subjectKeyPair = keyPairGenerator.GenerateKeyPair();

            certificateGenerator.SetPublicKey(subjectKeyPair.Public);


            // Get Private key for the Certificate
            TextWriter textWriter = new StringWriter();
            PemWriter pemWriter = new PemWriter(textWriter);
            pemWriter.WriteObject(subjectKeyPair.Private);
            pemWriter.Writer.Flush();

            string privateKeyString = textWriter.ToString();

            var issuerKeyPair = subjectKeyPair;
            var signatureFactory = new Asn1SignatureFactory(Constants.DEFAULT_SIGNATURE_ALOGIRTHM, issuerKeyPair.Private);
            var bouncyCert = certificateGenerator.Generate(signatureFactory);

            // Lets convert it to X509Certificate2
            X509Certificate2 certificate;

            Pkcs12Store store = new Pkcs12StoreBuilder().Build();

            store.SetKeyEntry($"{agentGuid}_key", new AsymmetricKeyEntry(subjectKeyPair.Private), new[] { new X509CertificateEntry(bouncyCert) });

            string exportpw = Guid.NewGuid().ToString("x");

            using (var ms = new MemoryStream())
            {
                store.Save(ms, exportpw.ToCharArray(), random);
                certificate = new X509Certificate2(ms.ToArray(), exportpw, X509KeyStorageFlags.Exportable);
            }

            // Get the value.
            string resultsTrue = certificate.ToString(true);

            //Get Certificate in PEM format
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("-----BEGIN CERTIFICATE-----");
            builder.AppendLine(
                Convert.ToBase64String(certificate.RawData, Base64FormattingOptions.InsertLineBreaks));
            builder.AppendLine("-----END CERTIFICATE-----");

            Console.WriteLine("Writing certificate and key to two files");

            string cert_location = "C://oms.crt";
            string key_location = "C://oms.key";
            try
            {
                if (!String.IsNullOrEmpty(Environment.GetEnvironmentVariable("CI_CERT_LOCATION")))
                {
                    cert_location = Environment.GetEnvironmentVariable("CI_CERT_LOCATION");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to read env variables (CI_CERT_LOCATION)" + ex.Message);
            }

            try
            {
                if (!String.IsNullOrEmpty(Environment.GetEnvironmentVariable("CI_KEY_LOCATION")))
                {
                    key_location = Environment.GetEnvironmentVariable("CI_KEY_LOCATION");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to read env variables (CI_KEY_LOCATION)" + ex.Message);
            }


            File.WriteAllText(cert_location, builder.ToString());
            File.WriteAllText(key_location, privateKeyString);

            return certificate;
        }

        // Delete the certificate and key files
        private static void DeleteCertificateAndKeyFile()
        {
            File.Delete(Environment.GetEnvironmentVariable("CI_CERT_LOCATION"));
            File.Delete(Environment.GetEnvironmentVariable("CI_KEY_LOCATION"));
        }

        private static string Sign(string requestdate, string contenthash, string key)
        {
            var signatureBuilder = new StringBuilder();
            signatureBuilder.Append(requestdate);
            signatureBuilder.Append("\n");
            signatureBuilder.Append(contenthash);
            signatureBuilder.Append("\n");
            string rawsignature = signatureBuilder.ToString();

            //string rawsignature = contenthash;

            HMACSHA256 hKey = new HMACSHA256(Convert.FromBase64String(key));
            return Convert.ToBase64String(hKey.ComputeHash(Encoding.UTF8.GetBytes(rawsignature)));
        }

        public static void RegisterWithOms(X509Certificate2 cert,
        string AgentGuid,
        string logAnalyticsWorkspaceId,
        string logAnalyticsWorkspaceKey,
        string logAnalyticsWorkspaceDomain,
        string proxyEndpoint)
        {

            string rawCert = Convert.ToBase64String(cert.GetRawCertData()); //base64 binary
            string hostName = Dns.GetHostName();

            string date = DateTime.Now.ToString("O");

            string xmlContent = "<?xml version=\"1.0\"?>" +
                "<AgentTopologyRequest xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/\">" +
                "<FullyQualfiedDomainName>"
                 + hostName
                + "</FullyQualfiedDomainName>" +
                "<EntityTypeId>"
                    + AgentGuid
                + "</EntityTypeId>" +
                "<AuthenticationCertificate>"
                  + rawCert
                + "</AuthenticationCertificate>" +
                "</AgentTopologyRequest>";

            SHA256 sha256 = SHA256.Create();

            string contentHash = Convert.ToBase64String(sha256.ComputeHash(Encoding.ASCII.GetBytes(xmlContent)));

            string authKey = string.Format("{0}; {1}", logAnalyticsWorkspaceId, Sign(date, contentHash, logAnalyticsWorkspaceKey));

            HttpClientHandler clientHandler = new HttpClientHandler();

            clientHandler.ClientCertificates.Add(cert);

            if (!string.IsNullOrEmpty(proxyEndpoint))
            {
                var parts = proxyEndpoint.Split("@");
                if (parts.Length != 2)
                {
                    Console.WriteLine("Invalid proxy endpoint configured hence ignoring the proxy configuration. Supported format should be http(s)://<user>:<pwd>@<hostOrIP>:<port>");
                }
                else
                {
                    var protocol = "";
                    if (!string.IsNullOrWhiteSpace(parts[0]))
                    {
                        var tempProtocolPrefix = parts[0].Split("//");
                        if (tempProtocolPrefix.Length == 2)
                        {
                            protocol = tempProtocolPrefix[0].Split(":")[0];
                            protocol = protocol.ToLower();
                        }
                    }

                    if (protocol != "http" && protocol != "https")
                    {
                        Console.WriteLine("Unsupported protocol in the proxy endpoint hence ignoring the proxy configuration. Supported protocol for the Proxy endpoint is http or https");
                    }
                    else
                    {

                        string proxyhostAndPort = parts[1];
                        var proxyURI = new Uri(string.Format("{0}://{1}", protocol, proxyhostAndPort));
                        var tempParts = parts[0].Split("//");
                        if (tempParts.Length != 2)
                        {
                            Console.WriteLine("Invalid proxy endpoint hence ignoring the proxy configuration. Supported format should be http(s)://<user>:<pwd>@<hostOrIP>:<port>");
                        }
                        else
                        {
                            var userNameAndPassword = tempParts[1].Split(":");
                            var username = userNameAndPassword[0];
                            var password = userNameAndPassword[1];
                            var credentials = new NetworkCredential(username, password);
                            //set proxy
                            clientHandler.Proxy = new WebProxy(proxyURI, true, null, credentials);
                        }
                    }
                }
            }

            var client = new HttpClient(clientHandler);

            string url = "https://" + logAnalyticsWorkspaceId + ".oms." + logAnalyticsWorkspaceDomain + "/AgentService.svc/AgentTopologyRequest";

            Console.WriteLine("OMS endpoint Url : {0}", url);

            client.DefaultRequestHeaders.Add("x-ms-Date", date);
            client.DefaultRequestHeaders.Add("x-ms-version", "August, 2014");
            client.DefaultRequestHeaders.Add("x-ms-SHA256_Content", contentHash);
            client.DefaultRequestHeaders.TryAddWithoutValidation("Authorization", authKey);
            client.DefaultRequestHeaders.Add("user-agent", "MonitoringAgent/OneAgent");
            client.DefaultRequestHeaders.Add("Accept-Language", "en-US");


            HttpContent httpContent = new StringContent(xmlContent, Encoding.UTF8);

            httpContent.Headers.ContentType = new MediaTypeHeaderValue("application/xml");


            Console.WriteLine("sent registration request");

            Task<HttpResponseMessage> response = client.PostAsync(new Uri(url), httpContent);

            Console.WriteLine("waiting response for registration request : {0}", response.Result.StatusCode);

            response.Wait();

            Console.WriteLine("registration request processed");

            Console.WriteLine("Response result status code : {0}", response.Result.StatusCode);

            HttpContent responseContent = response.Result.Content;

            string result = responseContent.ReadAsStringAsync().Result;

            Console.WriteLine("Return Result: " + result);

            Console.WriteLine(response.Result);

            if (response.Result.StatusCode != HttpStatusCode.OK)
            {
                DeleteCertificateAndKeyFile();
            }
        }

        public static void RegisterWithOmsWithBasicRetryAsync(X509Certificate2 cert,
        string AgentGuid,
        string logAnalyticsWorkspaceId,
        string logAnalyticsWorkspaceKey,
        string logAnalyticsWorkspaceDomain,
        string proxyEndpoint)
        {
            int currentRetry = 0;

            for (; ; )
            {
                try
                {
                    RegisterWithOms(cert,
                       AgentGuid,
                       logAnalyticsWorkspaceId,
                       logAnalyticsWorkspaceKey,
                       logAnalyticsWorkspaceDomain,
                       proxyEndpoint);

                    // Return or break.
                    break;
                }
                catch (Exception ex)
                {

                    currentRetry++;

                    // Check if the exception thrown was a transient exception
                    // based on the logic in the error detection strategy.
                    // Determine whether to retry the operation, as well as how
                    // long to wait, based on the retry strategy.
                    if (currentRetry > 3)
                    {
                        // If this isn't a transient error or we shouldn't retry,
                        // rethrow the exception.
                        Console.WriteLine("exception occurred : {0}", ex.Message);
                        throw;
                    }
                }

                // Wait to retry the operation.
                // Consider calculating an exponential delay here and
                // using a strategy best suited for the operation and fault.
                Task.Delay(1000);
            }
        }

        public static X509Certificate2 RegisterAgentWithOMS(string logAnalyticsWorkspaceId,
            string logAnalyticsWorkspaceKey,
            string logAnalyticsWorkspaceDomain,
            string proxyEndpoint)
        {
            X509Certificate2 agentCert = null;

            var agentGuid = Guid.NewGuid().ToString("B");

            try
            {
                Environment.SetEnvironmentVariable("CI_AGENT_GUID", agentGuid);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to set env variable (CI_AGENT_GUID)" + ex.Message);
            }

            try
            {
                agentCert = CreateSelfSignedCertificate(agentGuid, logAnalyticsWorkspaceId);

                if (agentCert == null)
                {
                    throw new Exception($"creating self-signed certificate failed for agentGuid : {agentGuid} and workspace: {logAnalyticsWorkspaceId}");
                }

                Console.WriteLine($"Successfully created self-signed certificate  for agentGuid : {agentGuid} and workspace: {logAnalyticsWorkspaceId}");

                RegisterWithOmsWithBasicRetryAsync(agentCert,
                    agentGuid,
                    logAnalyticsWorkspaceId,
                    logAnalyticsWorkspaceKey,
                    logAnalyticsWorkspaceDomain,
                    proxyEndpoint
                    );

            }
            catch (Exception ex)
            {
                Console.WriteLine("Registering agent with OMS failed : {0}", ex.Message.ToString());

                throw ex;
            }

            return agentCert;
        }

        static void Main(string[] args)
        {
            Console.WriteLine("Dotnet executable starting :");
            string logAnalyticsWorkspaceID = "";
            string logAnalyticsWorkspaceSharedKey = "";
            string logAnayticsDomain = Constants.DEFAULT_LOG_ANALYTICS_WORKSPACE_DOMAIN;
            string proxyEndpoint = "";

            try
            {
                if (!String.IsNullOrEmpty(Environment.GetEnvironmentVariable("WSID")))
                {
                    logAnalyticsWorkspaceID = Environment.GetEnvironmentVariable("WSID");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to read env variables (WSID)" + ex.Message);
            }

            try
            {
              // WSKEY isn't stored as an environment variable
              logAnalyticsWorkspaceSharedKey = File.ReadAllText("C:/etc/ama-logs-secret/KEY").Trim();
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to read secret (WSKEY)" + ex.Message);
            }

            try
            {
                if (!String.IsNullOrEmpty(Environment.GetEnvironmentVariable("DOMAIN")))
                {
                    logAnayticsDomain = Environment.GetEnvironmentVariable("DOMAIN");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to read env variables (DOMAIN)" + ex.Message);
            }

            try
            {
                if (!String.IsNullOrEmpty(Environment.GetEnvironmentVariable("DOMAIN")))
                {
                    logAnayticsDomain = Environment.GetEnvironmentVariable("DOMAIN");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to read env variables (DOMAIN)" + ex.Message);
            }

            try
            {
                if (!String.IsNullOrEmpty(Environment.GetEnvironmentVariable("PROXY")))
                {
                    Console.WriteLine("Proxy configured");
                    proxyEndpoint = Environment.GetEnvironmentVariable("PROXY");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to read env variables (PROXY)" + ex.Message);
            }


            X509Certificate2 clientCertificate = RegisterAgentWithOMS(logAnalyticsWorkspaceID, logAnalyticsWorkspaceSharedKey, logAnayticsDomain, proxyEndpoint);
        }
    }
}
