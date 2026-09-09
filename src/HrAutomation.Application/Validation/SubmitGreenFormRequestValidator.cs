using FluentValidation;
using HrAutomation.Application.Contracts;

namespace HrAutomation.Application.Validation;

public sealed class SubmitGreenFormRequestValidator : AbstractValidator<SubmitGreenFormRequest>
{
    public SubmitGreenFormRequestValidator()
    {
        RuleForEach(x => x.EmploymentHistory).ChildRules(e =>
        {
            e.RuleFor(x => x.EmployerName).NotEmpty().MaximumLength(200);
        });
        RuleForEach(x => x.Education).ChildRules(e =>
        {
            e.RuleFor(x => x.Institution).NotEmpty().MaximumLength(200);
            e.RuleFor(x => x.Qualification).NotEmpty().MaximumLength(200);
            e.RuleFor(x => x.Year).InclusiveBetween(1950, DateTime.UtcNow.Year);
        });
    }
}
