using System;
using Microsoft.EntityFrameworkCore.Migrations;
using NetTopologySuite.Geometries;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Trilho.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "city_id",
                table: "lines",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "cities",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    state = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    country = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    latitude = table.Column<double>(type: "double precision", nullable: false),
                    longitude = table.Column<double>(type: "double precision", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_cities", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "gtfs_agencies",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    agency_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    agency_name = table.Column<string>(type: "text", nullable: false),
                    agency_url = table.Column<string>(type: "text", nullable: false),
                    agency_timezone = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gtfs_agencies", x => x.id);
                    table.UniqueConstraint("AK_gtfs_agencies_agency_id", x => x.agency_id);
                });

            migrationBuilder.CreateTable(
                name: "gtfs_calendars",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    service_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    monday = table.Column<bool>(type: "boolean", nullable: false),
                    tuesday = table.Column<bool>(type: "boolean", nullable: false),
                    wednesday = table.Column<bool>(type: "boolean", nullable: false),
                    thursday = table.Column<bool>(type: "boolean", nullable: false),
                    friday = table.Column<bool>(type: "boolean", nullable: false),
                    saturday = table.Column<bool>(type: "boolean", nullable: false),
                    sunday = table.Column<bool>(type: "boolean", nullable: false),
                    start_date = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    end_date = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gtfs_calendars", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "gtfs_stops",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    stop_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    stop_name = table.Column<string>(type: "text", nullable: false),
                    stop_lat = table.Column<double>(type: "double precision", nullable: false),
                    stop_lon = table.Column<double>(type: "double precision", nullable: false),
                    stop_code = table.Column<string>(type: "text", nullable: true),
                    location = table.Column<Point>(type: "geography(Point,4326)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gtfs_stops", x => x.id);
                    table.UniqueConstraint("AK_gtfs_stops_stop_id", x => x.stop_id);
                });

            migrationBuilder.CreateTable(
                name: "gtfs_routes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    route_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    agency_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    route_short_name = table.Column<string>(type: "text", nullable: false),
                    route_long_name = table.Column<string>(type: "text", nullable: false),
                    route_color = table.Column<string>(type: "character varying(6)", maxLength: 6, nullable: false),
                    route_text_color = table.Column<string>(type: "character varying(6)", maxLength: 6, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gtfs_routes", x => x.id);
                    table.UniqueConstraint("AK_gtfs_routes_route_id", x => x.route_id);
                    table.ForeignKey(
                        name: "FK_gtfs_routes_gtfs_agencies_agency_id",
                        column: x => x.agency_id,
                        principalTable: "gtfs_agencies",
                        principalColumn: "agency_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "gtfs_trips",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    trip_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    route_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    service_id = table.Column<string>(type: "text", nullable: false),
                    trip_headsign = table.Column<string>(type: "text", nullable: true),
                    direction_id = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gtfs_trips", x => x.id);
                    table.UniqueConstraint("AK_gtfs_trips_trip_id", x => x.trip_id);
                    table.ForeignKey(
                        name: "FK_gtfs_trips_gtfs_routes_route_id",
                        column: x => x.route_id,
                        principalTable: "gtfs_routes",
                        principalColumn: "route_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "gtfs_stop_times",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    trip_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    stop_id = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    stop_sequence = table.Column<int>(type: "integer", nullable: false),
                    arrival_time = table.Column<string>(type: "text", nullable: true),
                    departure_time = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gtfs_stop_times", x => x.id);
                    table.ForeignKey(
                        name: "FK_gtfs_stop_times_gtfs_stops_stop_id",
                        column: x => x.stop_id,
                        principalTable: "gtfs_stops",
                        principalColumn: "stop_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_gtfs_stop_times_gtfs_trips_trip_id",
                        column: x => x.trip_id,
                        principalTable: "gtfs_trips",
                        principalColumn: "trip_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_lines_city_id",
                table: "lines",
                column: "city_id");

            migrationBuilder.CreateIndex(
                name: "IX_cities_name_state",
                table: "cities",
                columns: new[] { "name", "state" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_agencies_agency_id",
                table: "gtfs_agencies",
                column: "agency_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_calendars_service_id",
                table: "gtfs_calendars",
                column: "service_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_routes_agency_id",
                table: "gtfs_routes",
                column: "agency_id");

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_routes_route_id",
                table: "gtfs_routes",
                column: "route_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_stop_times_stop_id",
                table: "gtfs_stop_times",
                column: "stop_id");

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_stop_times_trip_id_stop_sequence",
                table: "gtfs_stop_times",
                columns: new[] { "trip_id", "stop_sequence" });

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_stops_stop_id",
                table: "gtfs_stops",
                column: "stop_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_trips_route_id",
                table: "gtfs_trips",
                column: "route_id");

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_trips_trip_id",
                table: "gtfs_trips",
                column: "trip_id",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_lines_cities_city_id",
                table: "lines",
                column: "city_id",
                principalTable: "cities",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_lines_cities_city_id",
                table: "lines");

            migrationBuilder.DropTable(
                name: "cities");

            migrationBuilder.DropTable(
                name: "gtfs_calendars");

            migrationBuilder.DropTable(
                name: "gtfs_stop_times");

            migrationBuilder.DropTable(
                name: "gtfs_stops");

            migrationBuilder.DropTable(
                name: "gtfs_trips");

            migrationBuilder.DropTable(
                name: "gtfs_routes");

            migrationBuilder.DropTable(
                name: "gtfs_agencies");

            migrationBuilder.DropIndex(
                name: "IX_lines_city_id",
                table: "lines");

            migrationBuilder.DropColumn(
                name: "city_id",
                table: "lines");
        }
    }
}
