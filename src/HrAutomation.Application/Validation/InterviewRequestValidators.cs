using FluentValidation;
using HrAutomation.Application.Contracts;

namespace HrAutomation.Application.Validation;

public sealed class ScheduleInterviewRequestValidator : AbstractValidator<ScheduleInterviewRequest>
{
    public ScheduleInterviewRequestValidator()
    {
        RuleFor(x => x.CandidateApplicationId).NotEmpty();
        RuleFor(x => x.InterviewRoundDefinitionId).NotEmpty();
        RuleFor(x => x.ScheduledEndUtc).GreaterThan(x => x.ScheduledStartUtc)
            .WithMessage("ScheduledEndUtc must be after ScheduledStartUtc.");
        RuleFor(x => x.TimeZoneId).MaximumLength(60);
        RuleFor(x => x.LocationOrLink).MaximumLength(500);
    }
}

public sealed class SubmitInterviewFeedbackRequestValidator : AbstractValidator<SubmitInterviewFeedbackRequest>
{
    public SubmitInterviewFeedbackRequestValidator()
    {
        RuleFor(x => x.Outcome).NotEmpty().Must(o => o is "select" or "reject")
            .WithMessage("Outcome must be 'select' or 'reject'.");
        RuleFor(x => x.CommunicationScore).InclusiveBetween(1m, 5m).When(x => x.CommunicationScore.HasValue);
        RuleFor(x => x.TechnicalScore).InclusiveBetween(1m, 5m).When(x => x.TechnicalScore.HasValue);
        RuleFor(x => x.Notes).NotEmpty().MaximumLength(2000);
    }
}
