using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trilho.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddIsAnonymousToUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "is_anonymous",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "is_anonymous",
                table: "users");
        }
    }
}
