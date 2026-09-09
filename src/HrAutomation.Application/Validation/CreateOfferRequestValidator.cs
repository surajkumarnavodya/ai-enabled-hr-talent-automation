using FluentValidation;
using HrAutomation.Application.Contracts;

namespace HrAutomation.Application.Validation;

public sealed class CreateOfferRequestValidator : AbstractValidator<CreateOfferRequest>
{
    public CreateOfferRequestValidator()
    {
        RuleFor(x => x.CandidateApplicationId).NotEmpty();
    }
}
