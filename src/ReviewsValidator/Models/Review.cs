using System;
using System.Text.Json.Serialization;

namespace ReviewsValidator.Models
{
    public class Review
    {
        public string PartitionKey { get; set; }
        public string RowKey { get; set; }
        [JsonPropertyName("review")]
        public string ReviewContent { get; set; }
        [JsonPropertyName("rating")]
        public int Rating { get; set; }
        [JsonPropertyName("userId")]
        public Guid UserId { get; set; }
        [JsonPropertyName("createdTime")]
        public DateTime CreatedTime { get; set; }
        [JsonPropertyName("productId")]
        public Guid ProductId { get; set; }
    }
}
