using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Trilho.Infrastructure.Services;

public interface IFcmService
{
    Task<bool> SendNotificationAsync(string token, string title, string body, Dictionary<string, string>? data = null);
    Task<int> SendToTopicAsync(string topic, string title, string body, Dictionary<string, string>? data = null);
    Task<int> SendToUsersAsync(IEnumerable<Guid> userIds, string title, string body, Dictionary<string, string>? data = null);
}

public class FcmService : IFcmService
{
    private readonly FirebaseMessaging? _messaging;
    private readonly ILogger<FcmService> _logger;
    private readonly bool _isEnabled;

    public FcmService(IConfiguration config, ILogger<FcmService> logger)
    {
        _logger = logger;
        
        var credentialsPath = config["Firebase:CredentialsPath"];
        _isEnabled = !string.IsNullOrWhiteSpace(credentialsPath);

        if (_isEnabled)
        {
            try
            {
                if (FirebaseApp.DefaultInstance == null)
                {
                    var credential = CredentialFactory.FromFile<ServiceAccountCredential>(credentialsPath!).ToGoogleCredential();
                    FirebaseApp.Create(new AppOptions { Credential = credential });
                }
                _messaging = FirebaseMessaging.DefaultInstance;
                _logger.LogInformation("Firebase Messaging initialized successfully");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize Firebase Messaging");
                _isEnabled = false;
            }
        }
        else
        {
            _logger.LogWarning("Firebase credentials not configured. Push notifications disabled.");
        }
    }

    public async Task<bool> SendNotificationAsync(
        string token, 
        string title, 
        string body, 
        Dictionary<string, string>? data = null)
    {
        if (!_isEnabled || _messaging == null)
        {
            _logger.LogDebug("FCM disabled, skipping notification to token {Token}", token[..8]);
            return false;
        }

        try
        {
            var message = new Message
            {
                Token = token,
                Notification = new Notification
                {
                    Title = title,
                    Body = body,
                },
                Data = data ?? new Dictionary<string, string>(),
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = "trilho_alerts",
                        DefaultSound = true,
                    }
                },
                Apns = new ApnsConfig
                {
                    Aps = new Aps
                    {
                        Sound = "default",
                        Badge = 1,
                    }
                }
            };

            var result = await _messaging.SendAsync(message);
            _logger.LogInformation("FCM notification sent: {MessageId}", result);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send FCM notification to token {Token}", token[..8]);
            return false;
        }
    }

    public async Task<int> SendToTopicAsync(
        string topic, 
        string title, 
        string body, 
        Dictionary<string, string>? data = null)
    {
        if (!_isEnabled || _messaging == null)
        {
            _logger.LogDebug("FCM disabled, skipping topic notification to {Topic}", topic);
            return 0;
        }

        try
        {
            var message = new Message
            {
                Topic = topic,
                Notification = new Notification
                {
                    Title = title,
                    Body = body,
                },
                Data = data ?? new Dictionary<string, string>(),
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = "trilho_alerts",
                    }
                },
                Apns = new ApnsConfig
                {
                    Aps = new Aps { Sound = "default" }
                }
            };

            var result = await _messaging.SendAsync(message);
            _logger.LogInformation("FCM topic notification sent to {Topic}: {MessageId}", topic, result);
            return 1;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send FCM topic notification to {Topic}", topic);
            return 0;
        }
    }

    public async Task<int> SendToUsersAsync(
        IEnumerable<Guid> userIds, 
        string title, 
        string body, 
        Dictionary<string, string>? data = null)
    {
        return 0;
    }
}
