using HrAutomation.Domain;
using HrAutomation.Domain.Enums;

namespace HrAutomation.Tests;

public class WorkflowStateMachineTests
{
    [Theory]
    [InlineData(WorkflowState.TanDraft, WorkflowState.TanApproved, true)]
    [InlineData(WorkflowState.TanDraft, WorkflowState.TanCancelled, true)]
    [InlineData(WorkflowState.TanDraft, WorkflowState.EmployeeCreated, false)]
    [InlineData(WorkflowState.TanApproved, WorkflowState.MatchingInProgress, true)]
    [InlineData(WorkflowState.L1FeedbackCaptured, WorkflowState.L1Selected, true)]
    [InlineData(WorkflowState.L1FeedbackCaptured, WorkflowState.L2Scheduled, false)]
    [InlineData(WorkflowState.L2Selected, WorkflowState.ClientInterviewScheduled, true)]
    [InlineData(WorkflowState.L2Selected, WorkflowState.FinalSelectionPendingApproval, true)]
    [InlineData(WorkflowState.OfferSent, WorkflowState.OfferAccepted, true)]
    [InlineData(WorkflowState.OfferSent, WorkflowState.EmployeeCreated, false)]
    [InlineData(WorkflowState.EmployeeCreated, WorkflowState.ApplicationClosed, false)]
    public void CanTransition_ReturnsExpected(WorkflowState from, WorkflowState to, bool expected)
    {
        Assert.Equal(expected, WorkflowStateMachine.CanTransition(from, to));
    }

    [Fact]
    public void AllowedNextStates_EmptyForTerminalStates()
    {
        Assert.Empty(WorkflowStateMachine.AllowedNextStates(WorkflowState.EmployeeCreated));
        Assert.Empty(WorkflowStateMachine.AllowedNextStates(WorkflowState.ApplicationClosed));
    }

    [Fact]
    public void AllowedNextStates_NonEmptyForTanDraft()
    {
        var next = WorkflowStateMachine.AllowedNextStates(WorkflowState.TanDraft);
        Assert.Contains(WorkflowState.TanApproved, next);
        Assert.Contains(WorkflowState.TanCancelled, next);
    }
}
