using Trilho.Domain.Entities;
using Xunit;

public class VipAccessTests
{
    [Fact]
    public void CanQuery_WhenVip_ReturnsTrueRegardlessOfPremium()
    {
        var user = new User { IsVip = true, IsPremium = false };
        Assert.True(user.CanQuery);
    }

    [Fact]
    public void CanQuery_WhenPremiumNotVip_ReturnsTrue()
    {
        var user = new User { IsPremium = true, IsVip = false };
        Assert.True(user.CanQuery);
    }

    [Fact]
    public void CanQuery_WhenNeitherPremiumNorVip_ReturnsFalse()
    {
        var user = new User { IsPremium = false, IsVip = false };
        Assert.False(user.CanQuery);
    }
}
