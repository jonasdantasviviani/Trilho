using System;
using Microsoft.EntityFrameworkCore.Migrations;
using NetTopologySuite.Geometries;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Trilho.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:postgis", ",,");

            migrationBuilder.CreateTable(
                name: "lines",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    code = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    type = table.Column<string>(type: "text", nullable: false),
                    color_hex = table.Column<string>(type: "char(6)", nullable: false),
                    headway_peak_sec = table.Column<int>(type: "integer", nullable: false),
                    headway_off_peak_sec = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_lines", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    is_premium = table.Column<bool>(type: "boolean", nullable: false),
                    daily_queries_used = table.Column<int>(type: "integer", nullable: false),
                    queries_reset_at = table.Column<DateOnly>(type: "date", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "line_status",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    line_id = table.Column<int>(type: "integer", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    message = table.Column<string>(type: "text", nullable: true),
                    source_url = table.Column<string>(type: "text", nullable: true),
                    captured_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_line_status", x => x.id);
                    table.ForeignKey(
                        name: "FK_line_status_lines_line_id",
                        column: x => x.line_id,
                        principalTable: "lines",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "stations",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    external_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    line_id = table.Column<int>(type: "integer", nullable: false),
                    sequence = table.Column<int>(type: "integer", nullable: false),
                    location = table.Column<Point>(type: "geography(Point,4326)", nullable: false),
                    capacity = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_stations", x => x.id);
                    table.ForeignKey(
                        name: "FK_stations_lines_line_id",
                        column: x => x.line_id,
                        principalTable: "lines",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "crowd_snapshots",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    station_id = table.Column<int>(type: "integer", nullable: false),
                    user_count = table.Column<int>(type: "integer", nullable: false),
                    inferred_density = table.Column<decimal>(type: "numeric(4,2)", precision: 4, scale: 2, nullable: false),
                    density_level = table.Column<string>(type: "text", nullable: false),
                    source = table.Column<string>(type: "text", nullable: false),
                    captured_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_crowd_snapshots", x => x.id);
                    table.ForeignKey(
                        name: "FK_crowd_snapshots_stations_station_id",
                        column: x => x.station_id,
                        principalTable: "stations",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "historical_demands",
                columns: table => new
                {
                    station_id = table.Column<int>(type: "integer", nullable: false),
                    day_type = table.Column<string>(type: "text", nullable: false),
                    hour = table.Column<short>(type: "smallint", nullable: false),
                    avg_passengers = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_historical_demands", x => new { x.station_id, x.day_type, x.hour });
                    table.ForeignKey(
                        name: "FK_historical_demands_stations_station_id",
                        column: x => x.station_id,
                        principalTable: "stations",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_pings",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    station_id = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_pings", x => x.id);
                    table.ForeignKey(
                        name: "FK_user_pings_stations_station_id",
                        column: x => x.station_id,
                        principalTable: "stations",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_user_pings_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_crowd_snapshots_station_id_captured_at",
                table: "crowd_snapshots",
                columns: new[] { "station_id", "captured_at" });

            migrationBuilder.CreateIndex(
                name: "IX_line_status_line_id_captured_at",
                table: "line_status",
                columns: new[] { "line_id", "captured_at" });

            migrationBuilder.CreateIndex(
                name: "IX_lines_code",
                table: "lines",
                column: "code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_stations_line_id",
                table: "stations",
                column: "line_id");

            migrationBuilder.CreateIndex(
                name: "IX_user_pings_station_id",
                table: "user_pings",
                column: "station_id");

            migrationBuilder.CreateIndex(
                name: "IX_user_pings_user_id",
                table: "user_pings",
                column: "user_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "crowd_snapshots");

            migrationBuilder.DropTable(
                name: "historical_demands");

            migrationBuilder.DropTable(
                name: "line_status");

            migrationBuilder.DropTable(
                name: "user_pings");

            migrationBuilder.DropTable(
                name: "stations");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.DropTable(
                name: "lines");
        }
    }
}
