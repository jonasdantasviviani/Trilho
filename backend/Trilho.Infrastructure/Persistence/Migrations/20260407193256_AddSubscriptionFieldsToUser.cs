using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Trilho.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSubscriptionFieldsToUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_gtfs_routes_gtfs_agencies_agency_id",
                table: "gtfs_routes");

            migrationBuilder.DropForeignKey(
                name: "FK_gtfs_stop_times_gtfs_stops_stop_id",
                table: "gtfs_stop_times");

            migrationBuilder.DropForeignKey(
                name: "FK_gtfs_stop_times_gtfs_trips_trip_id",
                table: "gtfs_stop_times");

            migrationBuilder.DropForeignKey(
                name: "FK_gtfs_trips_gtfs_routes_route_id",
                table: "gtfs_trips");

            migrationBuilder.DropUniqueConstraint(
                name: "AK_gtfs_trips_trip_id",
                table: "gtfs_trips");

            migrationBuilder.DropIndex(
                name: "IX_gtfs_trips_route_id",
                table: "gtfs_trips");

            migrationBuilder.DropUniqueConstraint(
                name: "AK_gtfs_stops_stop_id",
                table: "gtfs_stops");

            migrationBuilder.DropIndex(
                name: "IX_gtfs_stop_times_stop_id",
                table: "gtfs_stop_times");

            migrationBuilder.DropUniqueConstraint(
                name: "AK_gtfs_routes_route_id",
                table: "gtfs_routes");

            migrationBuilder.DropIndex(
                name: "IX_gtfs_routes_agency_id",
                table: "gtfs_routes");

            migrationBuilder.DropUniqueConstraint(
                name: "AK_gtfs_agencies_agency_id",
                table: "gtfs_agencies");

            migrationBuilder.AddColumn<string>(
                name: "active_billing_id",
                table: "users",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "current_payment_method",
                table: "users",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "is_premium_until",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "subscription_cancelled_at",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "subscription_cancelled_by_user",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "subscription_started_at",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "tax_id",
                table: "users",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "user_device_tokens",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    token = table.Column<string>(type: "text", nullable: false),
                    platform = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    last_notified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_device_tokens", x => x.id);
                    table.ForeignKey(
                        name: "FK_user_device_tokens_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_user_device_tokens_token",
                table: "user_device_tokens",
                column: "token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_user_device_tokens_user_id",
                table: "user_device_tokens",
                column: "user_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "user_device_tokens");

            migrationBuilder.DropColumn(
                name: "active_billing_id",
                table: "users");

            migrationBuilder.DropColumn(
                name: "current_payment_method",
                table: "users");

            migrationBuilder.DropColumn(
                name: "is_premium_until",
                table: "users");

            migrationBuilder.DropColumn(
                name: "subscription_cancelled_at",
                table: "users");

            migrationBuilder.DropColumn(
                name: "subscription_cancelled_by_user",
                table: "users");

            migrationBuilder.DropColumn(
                name: "subscription_started_at",
                table: "users");

            migrationBuilder.DropColumn(
                name: "tax_id",
                table: "users");

            migrationBuilder.AddUniqueConstraint(
                name: "AK_gtfs_trips_trip_id",
                table: "gtfs_trips",
                column: "trip_id");

            migrationBuilder.AddUniqueConstraint(
                name: "AK_gtfs_stops_stop_id",
                table: "gtfs_stops",
                column: "stop_id");

            migrationBuilder.AddUniqueConstraint(
                name: "AK_gtfs_routes_route_id",
                table: "gtfs_routes",
                column: "route_id");

            migrationBuilder.AddUniqueConstraint(
                name: "AK_gtfs_agencies_agency_id",
                table: "gtfs_agencies",
                column: "agency_id");

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_trips_route_id",
                table: "gtfs_trips",
                column: "route_id");

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_stop_times_stop_id",
                table: "gtfs_stop_times",
                column: "stop_id");

            migrationBuilder.CreateIndex(
                name: "IX_gtfs_routes_agency_id",
                table: "gtfs_routes",
                column: "agency_id");

            migrationBuilder.AddForeignKey(
                name: "FK_gtfs_routes_gtfs_agencies_agency_id",
                table: "gtfs_routes",
                column: "agency_id",
                principalTable: "gtfs_agencies",
                principalColumn: "agency_id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_gtfs_stop_times_gtfs_stops_stop_id",
                table: "gtfs_stop_times",
                column: "stop_id",
                principalTable: "gtfs_stops",
                principalColumn: "stop_id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_gtfs_stop_times_gtfs_trips_trip_id",
                table: "gtfs_stop_times",
                column: "trip_id",
                principalTable: "gtfs_trips",
                principalColumn: "trip_id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_gtfs_trips_gtfs_routes_route_id",
                table: "gtfs_trips",
                column: "route_id",
                principalTable: "gtfs_routes",
                principalColumn: "route_id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
