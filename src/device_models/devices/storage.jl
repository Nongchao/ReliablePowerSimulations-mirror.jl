struct BookKeepingwReservationOutage <: PSI.AbstractStorageFormulation end
struct EndOfPeriodEnergyTargetOutage <: PSI.AbstractEnergyManagement end

function outage_constraints!(
    optimization_container::PSI.OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::PSI.DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, PSI.AbstractAffectFeedForward},
) where {T <: PSY.Storage, S <: PM.AbstractPowerModel, D <: PSI.AbstractStorageFormulation}

    parameters = PSI.model_has_parameters(optimization_container)
    resolution = PSI.model_resolution(optimization_container)

    forecast_label = "outage"
    constraint_infos = Vector{DeviceOutageConstraintInfo}()
    for d in devices
        name = PSY.get_name(d)
        info = DeviceOutageConstraintInfo(
            name,
            nothing,
            1.0,
            PSI.get_time_series(optimization_container, d, forecast_label),
        )
        push!(constraint_infos, info)
    end

    if !(isempty(devices))
        if parameters
            device_outage_ub_parameter!(
                optimization_container,
                constraint_infos,
                PSI.make_constraint_name(OUTAGE, T),
                PSI.make_variable_name(PSI.ActivePowerInVariable, T),
                PSI.UpdateRef{T}(OUTAGE, forecast_label),
            )
            device_outage_ub_parameter!(
                optimization_container,
                constraint_infos,
                PSI.make_constraint_name(OUTAGE, T),
                PSI.make_variable_name(PSI.ActivePowerOutVariable, T),
                PSI.UpdateRef{T}(OUTAGE, forecast_label),
            )
        else
            device_outage_ub!(
                optimization_container,
                constraint_infos,
                PSI.make_constraint_name(OUTAGE, T),
                PSI.make_variable_name(PSI.ActivePowerInVariable, T),
            )
            device_outage_ub!(
                optimization_container,
                constraint_infos,
                PSI.make_constraint_name(OUTAGE, T),
                PSI.make_variable_name(PSI.ActivePowerOutVariable, T),
            )
        end
    else
        @warn "Data doesn't contain generators of type $T, consider adjusting your formulation"
    end

    return
end
