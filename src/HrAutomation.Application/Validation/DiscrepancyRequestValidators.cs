using FluentValidation;
using HrAutomation.Application.Contracts;

namespace HrAutomation.Application.Validation;

public sealed class ResolveDiscrepancyRequestValidator : AbstractValidator<ResolveDiscrepancyRequest>
{
    public ResolveDiscrepancyRequestValidator()
    {
        RuleFor(x => x.Decision).NotEmpty().Must(d => d is "approved" or "rejected")
            .WithMessage("Decision must be 'approved' or 'rejected'.");
    }
}

public sealed class RequestReuploadRequestValidator : AbstractValidator<RequestReuploadRequest>
{
    public RequestReuploadRequestValidator()
    {
        RuleFor(x => x.Reason).MaximumLength(1000);
    }
}
