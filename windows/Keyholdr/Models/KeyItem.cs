using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using System.Windows.Media;

namespace Keyholdr.Models
{
    public class KeyItem
    {
        [JsonPropertyName("id")]
        public Guid Id { get; set; }

        [JsonPropertyName("platform")]
        public string Platform { get; set; } = string.Empty;

        [JsonPropertyName("label")]
        public string Label { get; set; } = string.Empty;

        [JsonPropertyName("tags")]
        public List<string> Tags { get; set; } = new();

        [JsonPropertyName("dateCreated")]
        public DateTime DateCreated { get; set; } = DateTime.UtcNow;

        public KeyItem() { }

        public KeyItem(string platform, string label, List<string>? tags = null, Guid? id = null)
        {
            Id = id ?? Guid.NewGuid();
            Platform = platform;
            Label = label;
            Tags = tags ?? new List<string>();
        }

        [JsonIgnore]
        public string Glyph
        {
            get
            {
                string p = Platform.ToLowerInvariant();

                // AI / ML
                if (p.Contains("openai") || p.Contains("chatgpt") || p.Contains("claude") || p.Contains("anthropic") || p.Contains("gemini") || p.Contains("huggingface") || p.Contains("cohere") || p.Contains("deepseek") || p.Contains("ollama"))
                    return "\uEA5C"; // Sparkles / Action Center Asterisk

                // Version Control
                if (p.Contains("github") || p.Contains("gitlab") || p.Contains("bitbucket") || p.Contains("git"))
                    return "\uE756"; // Terminal

                // Cloud & Hosting
                if (p.Contains("aws") || p.Contains("amazon") || p.Contains("azure") || p.Contains("cloudflare") || p.Contains("digitalocean") || p.Contains("heroku") || p.Contains("vercel") || p.Contains("netlify") || p.Contains("fly.io") || p.Contains("render"))
                    return "\uE753"; // Cloud

                // Databases / Backend services
                if (p.Contains("db") || p.Contains("database") || p.Contains("postgres") || p.Contains("mysql") || p.Contains("mongo") || p.Contains("sql") || p.Contains("redis") || p.Contains("supabase") || p.Contains("firebase") || p.Contains("dynamodb") || p.Contains("prisma") || p.Contains("hasura"))
                    return "\uF158"; // Database Server

                // Payments & E-commerce
                if (p.Contains("stripe") || p.Contains("paypal") || p.Contains("braintree") || p.Contains("adyen") || p.Contains("coinbase") || p.Contains("shopify"))
                    return "\uE8C7"; // Credit Card

                // Servers & Networking
                if (p.Contains("ssh") || p.Contains("server") || p.Contains("vps") || p.Contains("docker") || p.Contains("k8s") || p.Contains("kubernetes") || p.Contains("nginx"))
                    return "\uE961"; // Network

                // Communication, Collaboration & Productivity
                if (p.Contains("slack") || p.Contains("discord") || p.Contains("telegram") || p.Contains("teams") || p.Contains("zoom") || p.Contains("notion") || p.Contains("figma") || p.Contains("jira") || p.Contains("linear"))
                    return "\uE8F2"; // Message chat

                // Monitoring & Logging
                if (p.Contains("sentry") || p.Contains("datadog") || p.Contains("grafana") || p.Contains("prometheus") || p.Contains("mixpanel") || p.Contains("amplitude"))
                    return "\uE1E0"; // ECG Waveform / Heart

                // Email & Messaging APIs
                if (p.Contains("twilio") || p.Contains("sendgrid") || p.Contains("mailchimp") || p.Contains("postmark") || p.Contains("ses"))
                    return "\uE724"; // Send

                // Google ecosystem
                if (p.Contains("google"))
                    return "\uE128"; // Globe

                return "\uE8D7"; // Key (default)
            }
        }

        [JsonIgnore]
        public Brush SymbolBrush
        {
            get
            {
                string p = Platform.ToLowerInvariant();

                // AI / ML
                if (p.Contains("openai") || p.Contains("chatgpt")) return new SolidColorBrush(Color.FromRgb(0, 166, 153));
                if (p.Contains("claude") || p.Contains("anthropic")) return new SolidColorBrush(Color.FromRgb(241, 140, 46));
                if (p.Contains("gemini")) return new SolidColorBrush(Color.FromRgb(147, 51, 234));
                if (p.Contains("huggingface")) return new SolidColorBrush(Color.FromRgb(234, 179, 8));
                if (p.Contains("deepseek")) return new SolidColorBrush(Color.FromRgb(37, 99, 235));

                // Version Control
                if (p.Contains("github")) return new SolidColorBrush(Color.FromRgb(147, 51, 234));
                if (p.Contains("gitlab")) return new SolidColorBrush(Color.FromRgb(241, 140, 46));
                if (p.Contains("bitbucket")) return new SolidColorBrush(Color.FromRgb(37, 99, 235));
                if (p.Contains("git")) return new SolidColorBrush(Color.FromRgb(241, 140, 46));

                // Cloud & Providers
                if (p.Contains("aws") || p.Contains("amazon")) return new SolidColorBrush(Color.FromRgb(241, 140, 46));
                if (p.Contains("azure")) return new SolidColorBrush(Color.FromRgb(0, 120, 212));
                if (p.Contains("cloudflare")) return new SolidColorBrush(Color.FromRgb(241, 140, 46));
                if (p.Contains("digitalocean")) return new SolidColorBrush(Color.FromRgb(0, 107, 240));
                if (p.Contains("heroku")) return new SolidColorBrush(Color.FromRgb(118, 74, 188));
                if (p.Contains("vercel")) return new SolidColorBrush(Color.FromRgb(240, 240, 240)); // light color
                if (p.Contains("netlify")) return new SolidColorBrush(Color.FromRgb(0, 189, 165));

                // Databases & Backend
                if (p.Contains("supabase")) return new SolidColorBrush(Color.FromRgb(62, 207, 142));
                if (p.Contains("firebase")) return new SolidColorBrush(Color.FromRgb(255, 202, 40));
                if (p.Contains("postgres")) return new SolidColorBrush(Color.FromRgb(51, 102, 153));
                if (p.Contains("redis")) return new SolidColorBrush(Color.FromRgb(220, 53, 69));
                if (p.Contains("mongo")) return new SolidColorBrush(Color.FromRgb(40, 167, 69));
                if (p.Contains("db") || p.Contains("database") || p.Contains("mysql") || p.Contains("sql") || p.Contains("dynamodb")) return new SolidColorBrush(Color.FromRgb(40, 167, 69));

                // Payments
                if (p.Contains("stripe")) return new SolidColorBrush(Color.FromRgb(99, 91, 255));
                if (p.Contains("paypal")) return new SolidColorBrush(Color.FromRgb(0, 121, 193));
                if (p.Contains("shopify")) return new SolidColorBrush(Color.FromRgb(149, 191, 71));

                // Networking & VPS
                if (p.Contains("docker")) return new SolidColorBrush(Color.FromRgb(36, 150, 237));
                if (p.Contains("ssh") || p.Contains("server") || p.Contains("vps") || p.Contains("k8s") || p.Contains("kubernetes")) return new SolidColorBrush(Color.FromRgb(140, 140, 140));

                // Communication & Collaboration
                if (p.Contains("slack")) return new SolidColorBrush(Color.FromRgb(224, 30, 90));
                if (p.Contains("discord")) return new SolidColorBrush(Color.FromRgb(114, 137, 218));
                if (p.Contains("telegram")) return new SolidColorBrush(Color.FromRgb(0, 136, 204));
                if (p.Contains("notion")) return new SolidColorBrush(Color.FromRgb(240, 240, 240));
                if (p.Contains("figma")) return new SolidColorBrush(Color.FromRgb(162, 89, 255));

                // Monitoring
                if (p.Contains("sentry")) return new SolidColorBrush(Color.FromRgb(54, 43, 91));
                if (p.Contains("datadog")) return new SolidColorBrush(Color.FromRgb(99, 42, 160));

                // Mailing
                if (p.Contains("twilio")) return new SolidColorBrush(Color.FromRgb(242, 47, 70));
                if (p.Contains("sendgrid") || p.Contains("mailchimp")) return new SolidColorBrush(Color.FromRgb(0, 164, 228));

                // Google
                if (p.Contains("google")) return new SolidColorBrush(Color.FromRgb(66, 133, 244));

                return new SolidColorBrush(Color.FromRgb(251, 191, 36)); // Yellow (Default)
            }
        }
    }
}
