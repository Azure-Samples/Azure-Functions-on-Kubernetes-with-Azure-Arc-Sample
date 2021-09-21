// Default URL for triggering event grid function in the local environment.
// http://localhost:7071/runtime/webhooks/EventGrid?functionName={functionname}
using System;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.EventGrid.Models;
using Microsoft.Azure.WebJobs.Extensions.EventGrid;
using Microsoft.Extensions.Logging;
using ReviewsValidator.Models;
using System.Text.Json;
using ReviewsValidator.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs.Extensions.Http;
using System.Threading.Tasks;
using System.IO;

namespace ReviewsValidator
{
    public class ReviewsValidatorFunctions
    {
        private readonly IBlocklistValidatorService validator;

        public ReviewsValidatorFunctions(IBlocklistValidatorService validator)
        {
            this.validator = validator;
        }

        [FunctionName("ReviewsValidator")]
        [return: Table("Reviews", Connection = "ReviewsStorage")]
        public Review ReviewsValidator([EventGridTrigger] EventGridEvent eventGridEvent, ILogger log)
        {
            string message = eventGridEvent.Data.ToString();

            Review review = JsonSerializer.Deserialize<Review>(message);
            if (!validator.Validate(review.ReviewContent))
            {
                log.LogInformation($"Dropping message with banned word: {message}");
                return null;
            }

            review.RowKey = Guid.NewGuid().ToString();
            review.PartitionKey = review.ProductId.ToString();
            log.LogInformation($"Saving valid message: {message}");
            return review;
        }

        [FunctionName("ReviewsValidatorHealth")]
        public async Task<IActionResult> HealthCheck([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest req, ILogger log)
        {
            log.LogInformation("Health request received");

            using (StreamReader streamReader =  new StreamReader(req.Body))
            {                
                string requestBody = await streamReader.ReadToEndAsync();
                if (requestBody != string.Empty)
                    log.LogInformation($"Request body: {requestBody}");                
            }

            return (IActionResult) new OkResult();
        }
    }
}
