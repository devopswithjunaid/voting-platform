using System;
using System.Threading;
using Newtonsoft.Json;
using Npgsql;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var pgsql = OpenDbConnection("Server=db;Username=postgres;Password=postgres;");
            var redisConn = OpenRedisConnection("redis");
            var redis = redisConn.GetDatabase();

            var definition = new { vote = "", voter_id = "" };
            
            while (true)
            {
                Thread.Sleep(100);
                
                string json = redis.ListLeftPopAsync("votes").Result;
                if (json != null)
                {
                    var vote = JsonConvert.DeserializeAnonymousType(json, definition);
                    Console.WriteLine($"Processing vote: {vote.vote} by {vote.voter_id}");
                    UpdateVote(pgsql, vote.voter_id, vote.vote);
                }
            }
        }

        private static NpgsqlConnection OpenDbConnection(string connectionString)
        {
            NpgsqlConnection connection;
            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();
                    break;
                }
                catch (Exception)
                {
                    Console.WriteLine("Waiting for database...");
                    Thread.Sleep(1000);
                }
            }

            var command = connection.CreateCommand();
            command.CommandText = @"CREATE TABLE IF NOT EXISTS votes (
                                        id VARCHAR(255) NOT NULL UNIQUE,
                                        vote VARCHAR(255) NOT NULL
                                    )";
            command.ExecuteNonQuery();
            return connection;
        }

        private static ConnectionMultiplexer OpenRedisConnection(string hostname)
        {
            while (true)
            {
                try
                {
                    return ConnectionMultiplexer.Connect(hostname);
                }
                catch (Exception)
                {
                    Console.WriteLine("Waiting for Redis...");
                    Thread.Sleep(1000);
                }
            }
        }

        private static void UpdateVote(NpgsqlConnection connection, string voterId, string vote)
        {
            var command = connection.CreateCommand();
            try
            {
                command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote)";
                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);
                command.ExecuteNonQuery();
            }
            catch
            {
                command.CommandText = "UPDATE votes SET vote = @vote WHERE id = @id";
                command.ExecuteNonQuery();
            }
        }
    }
}
