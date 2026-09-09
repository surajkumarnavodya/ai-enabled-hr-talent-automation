using FluentValidation;
using HrAutomation.Application.Contracts;

namespace HrAutomation.Application.Validation;

public sealed class CreateTanRequestValidator : AbstractValidator<CreateTanRequest>
{
    public CreateTanRequestValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Location).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Grade).NotEmpty().MaximumLength(50);
        RuleFor(x => x.BudgetMin).GreaterThanOrEqualTo(0);
        RuleFor(x => x.BudgetMax).GreaterThanOrEqualTo(x => x.BudgetMin)
            .WithMessage("BudgetMax must be greater than or equal to BudgetMin.");
        RuleFor(x => x.InterviewStagesCount).InclusiveBetween(1, 5);
    }
}

public sealed class ApproveTanRequestValidator : AbstractValidator<ApproveTanRequest>
{
    public ApproveTanRequestValidator()
    {
        RuleFor(x => x.SourceVersion).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Comments).MaximumLength(2000);
    }
}
