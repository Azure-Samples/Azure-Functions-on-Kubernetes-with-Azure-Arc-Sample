using System;
using System.Linq;

namespace ReviewsValidator.Services
{
    public interface IBlocklistValidatorService
    {
        bool Validate(string input);
    }

    public class BlocklistValidatorService : IBlocklistValidatorService
    {
        private string[] blockWords = { "blockword", "banword", "badword" };
        public bool Validate(string input)
        {
            string lowercaseInput = input.ToLowerInvariant();
            return !blockWords.Any(word => lowercaseInput.Contains(word));
        }
    }
}