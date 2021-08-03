using System;
using Xunit;
using ReviewsValidator.Services;

namespace ReviewsValidatorTest
{
    public class BlocklistValidatorTest
    {
        [Fact]
        public void ReturnsTrueIfReviewDoesNotContainBlockedWord()
        {
            const string input = "message with no invalid words";
            BlocklistValidatorService validator = new BlocklistValidatorService();

            bool result = validator.Validate(input);

            Assert.True(result, $"Expected true with input '{input}'");

        }

        [Theory]
        [InlineData("message with banword inside")]
        [InlineData("banword at start of message")]
        [InlineData("message ending with banword")]
        [InlineData("message with BaNWorD in mixed case")]
        public void ReturnsFalseIfReviewContainsBlockedWord(string input)
        {
            BlocklistValidatorService validator = new BlocklistValidatorService();
            bool result = validator.Validate(input);
            Assert.False(result, $"Expected false with input '{input}'");

        }
    }
}
