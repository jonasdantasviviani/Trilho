using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;

namespace Trilho.Infrastructure.Services;

public interface IFirebaseTokenValidator
{
    Task<FirebaseToken?> ValidateAsync(string idToken, CancellationToken ct = default);
}

#pragma warning disable CS0618 // Type or member is obsolete
public class FirebaseTokenValidator : IFirebaseTokenValidator
{
    public FirebaseTokenValidator(IConfiguration config)
    {
        if (FirebaseApp.DefaultInstance != null) return;
        var serviceAccountJson = config["Firebase:ServiceAccountJson"];
        if (string.IsNullOrWhiteSpace(serviceAccountJson)) return;
        var json = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(serviceAccountJson));
        FirebaseApp.Create(new AppOptions
        {
            Credential = GoogleCredential.FromJson(json)
        });
    }

    public async Task<FirebaseToken?> ValidateAsync(string idToken, CancellationToken ct = default)
    {
        try
        {
            if (FirebaseApp.DefaultInstance is null) return null;
            return await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(idToken, ct);
        }
        catch
        {
            return null;
        }
    }
}
#pragma warning restore CS0618
