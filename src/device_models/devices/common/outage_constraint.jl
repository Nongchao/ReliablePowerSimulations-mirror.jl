function device_outage_parameter!(
    container::PSI.OptimizationContainer,
    T::Type{OutageCommitmentConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::PSI.DeviceModel{V, W},
    network_model::PSI.NetworkModel{X},
) where {V <: PSY.ThermalGen, W <: Union{ThermalStandardUCOutages, ThermalBasicUCOutages}, X <: PM.AbstractPowerModel}
    time_steps = PSI.get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.OnVariable(), V)
    varstop = PSI.get_variable(container, PSI.StopVariable(), V)
    varstart = PSI.get_variable(container, PSI.StartVariable(), V)
    initial_conditions_outage =
        PSI.get_initial_condition(container, InitialOutageStatus(), V)

    con_on = PSI.add_constraints_container!(
        container,
        T(),
        V,
        device_names,
        time_steps,
        meta = "on",
    )
    con_stop = PSI.add_constraints_container!(
        container,
        T(),
        V,
        device_names,
        time_steps,
        meta = "stop",
    )
    con_start = PSI.add_constraints_container!(
        container,
        T(),
        V,
        device_names,
        time_steps,
        meta = "start",
    )

    param_container = PSI.get_parameter(container, OutageTimeSeriesParameter(), V)

    multiplier =
        PSI.get_parameter_multiplier_array(container, OutageTimeSeriesParameter(), V)

    for ic in initial_conditions_outage
        name = PSI.get_component_name(ic)
        varz = JuMP.@variable(container.JuMPmodel, base_name = "outage_z_{$(name), 1}")
        vary = JuMP.@variable(container.JuMPmodel, base_name = "outage_y_{$(name), 1}")
        JuMP.@constraint(container.JuMPmodel, varz <= varon[name, 1])
        JuMP.@constraint(container.JuMPmodel, vary <= varon[name, 1])

        JuMP.@constraint(container.JuMPmodel, varz <= PSI.get_value(ic))

        param = PSI.get_parameter_column_refs(param_container, name)

        JuMP.@constraint(container.JuMPmodel, vary <= param[1])
        
        JuMP.@constraint(
            container.JuMPmodel,
            varz >= PSI.get_value(ic) + varon[name, 1] - 1.0
        )
        JuMP.@constraint(
            container.JuMPmodel,
            vary >= param[1] + varon[name, 1] - 1.0
        )

        con_on[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            varon[name, 1] <= param[1]
        )
        con_start[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            varstart[name, 1] <= param[1]
        )
        con_stop[name, 1] =
            JuMP.@constraint(container.JuMPmodel, varstop[name, 1] >= varz - vary)

        for t in time_steps[2:end]
            varz =
                JuMP.@variable(container.JuMPmodel, base_name = "outage_z_{$(name), $(t)}")
            vary =
                JuMP.@variable(container.JuMPmodel, base_name = "outage_y_{$(name), $(t)}")
            JuMP.@constraint(container.JuMPmodel, varz <= varon[name, t])
            JuMP.@constraint(container.JuMPmodel, vary <= varon[name, t])

            JuMP.@constraint(
                container.JuMPmodel,
                varz <= param[t - 1]
            )
            JuMP.@constraint(
                container.JuMPmodel,
                vary <= param[t]
            )

            JuMP.@constraint(
                container.JuMPmodel,
                varz >= param[t - 1] + varon[name, t] - 1.0
            )
            JuMP.@constraint(
                container.JuMPmodel,
                vary >= param[t] + varon[name, t] - 1.0
            )
            con_stop[name, t] =
                JuMP.@constraint(container.JuMPmodel, varstop[name, t] >= varz - vary)
            con_start[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                varstart[name, t] <= param[t]
            )
            con_on[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                varon[name, t] <= param[t]
            )
        end
    end
    return
end

function device_outage_ub_parameter!(
    container::PSI.OptimizationContainer,
    T::Type{OutageUpperBoundConstraint},
    ::Type{S},
    devices::IS.FlattenIteratorWrapper{V},
    model::PSI.DeviceModel{V, W},
    ::PSI.NetworkModel{X},
) where {
    V <: Union{
        PSY.HydroGen,
        PSY.HydroPumpedStorage,
        PSY.RenewableGen,
        PSY.Storage,
        PSY.ThermalGen,
    },
    S <: PSI.VariableType,
    W <: PSI.AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel
}
    time_steps = PSI.get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    varp = PSI.get_variable(container, S(), V)
    constraint = PSI.add_constraints_container!(
        container,
        T(),
        V,
        device_names,
        time_steps,
        meta = "power",
    )
    
    param_container = PSI.get_parameter(container, OutageTimeSeriesParameter(), V)

    multiplier =
        PSI.get_parameter_multiplier_array(container, OutageTimeSeriesParameter(), V)

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        param = PSI.get_parameter_column_refs(param_container, name)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            varp[name, t] <= param[t] * PSI.M_VALUE
        )
    end
    return
end

function device_outage_ub_parameter!(
    container::PSI.OptimizationContainer,
    T::Type{OutageUpperBoundConstraint},
    ::Type{S},
    devices::IS.FlattenIteratorWrapper{V},
    model::PSI.DeviceModel{V, W},
    ::PSI.NetworkModel{X},
) where {
    V <: Union{
        PSY.HydroGen,
        PSY.HydroPumpedStorage,
        PSY.RenewableGen,
        PSY.Storage,
        PSY.ThermalGen,
    },
    S <: PSI.ExpressionType,
    W <: PSI.AbstractDeviceFormulation,
    X <: PM.AbstractActivePowerModel,
}
    time_steps = PSI.get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    varp = PSI.get_expression(container, S(), V)
    constraint = PSI.add_constraints_container!(
        container,
        T(),
        V,
        device_names,
        time_steps,
        meta = "power",
    )
    param_container = PSI.get_parameter(container, OutageTimeSeriesParameter(), V)
    multiplier =
        PSI.get_parameter_multiplier_array(container, OutageTimeSeriesParameter(), V)

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        param = PSI.get_parameter_column_refs(param_container, name)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            varp[name, t] <= param[t] * PSI.M_VALUE
        )
    end
    return
end
