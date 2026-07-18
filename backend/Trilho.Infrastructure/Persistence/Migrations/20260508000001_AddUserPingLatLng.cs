using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trilho.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddUserPingLatLng : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "lat",
                table: "user_pings",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "lng",
                table: "user_pings",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "lat",
                table: "user_pings");

            migrationBuilder.DropColumn(
                name: "lng",
                table: "user_pings");
        }
    }
}
