using System.Text.Json;
using Microsoft.Azure.EventGrid.Models;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using ReviewsValidator;
using ReviewsValidator.Models;
using ReviewsValidator.Services;
using Xunit;

namespace ReviewsValidatorTest
{
    public class ReviewsValidatorFunctionsTest 
    {
        [Fact]
        public void ReturnsValidReviewWhenValidatorReturnsTrue()
        {
            IBlocklistValidatorService validator = CreateValidatorMock(true);
            ReviewsValidatorFunctions functions = new ReviewsValidatorFunctions(validator);
            EventGridEvent eventGridEvent = CreateEvent();
            Review expectedReview = JsonSerializer.Deserialize<Review>(eventGridEvent.Data.ToString());

            Review review = functions.ReviewsValidator(eventGridEvent, NullLogger.Instance);

            Assert.NotNull(review);
            Assert.Equal(expectedReview.CreatedTime, review.CreatedTime);
            Assert.Equal(expectedReview.ProductId, review.ProductId);
            Assert.Equal(expectedReview.Rating, review.Rating);
            Assert.Equal(expectedReview.ReviewContent, review.ReviewContent);
            Assert.Equal(expectedReview.UserId, review.UserId);
            Assert.Equal(expectedReview.ProductId.ToString(), review.PartitionKey);
            Assert.NotNull(review.RowKey);
        }


        [Fact]
        public void ReturnsNullWhenValidatorReturnsFalse()
        {
            IBlocklistValidatorService validator = CreateValidatorMock(false);
            ReviewsValidatorFunctions functions = new ReviewsValidatorFunctions(validator);

            Review review = functions.ReviewsValidator(CreateEvent(), NullLogger.Instance);

            Assert.Null(review);
        }

        private static IBlocklistValidatorService CreateValidatorMock(bool validateResult)
        {
            Mock<IBlocklistValidatorService> mock = new Mock<IBlocklistValidatorService>();
            mock.Setup(mockItem => mockItem.Validate(It.IsAny<string>())).Returns(validateResult);

            IBlocklistValidatorService validator = mock.Object;
            return validator;
        }
        
        private EventGridEvent CreateEvent()
        {
            return new EventGridEvent() { Data = CreateReview() };
        }

        private string CreateReview()
        {
            return
            $"{{" + 
                "\"review\": \"review message\"," + 
                "\"rating\": 5," + 
                "\"userId\": \"53261fcc-94a8-4bdf-81ee-d09163c4a124\"," + 
                "\"createdTime\": \"2020-03-11T21:03:07+00:00\"," + 
                "\"productId\": \"53261fcc-94a8-4bdf-81ee-d09163c4a124\"" + 
            "}";
        }
    }
}
