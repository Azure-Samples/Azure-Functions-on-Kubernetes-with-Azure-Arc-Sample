using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection;
using ReviewsValidator.Services;

[assembly: FunctionsStartup(typeof(ReviewsValidator.Startup))]

namespace ReviewsValidator
{
    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder builder)
        {
            builder.Services.AddSingleton<IBlocklistValidatorService>(new BlocklistValidatorService());
        }
    }
}