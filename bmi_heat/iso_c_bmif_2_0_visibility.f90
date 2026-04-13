! iso_c_bmif_2_0_visibility.f90
!
! Symbol visibility declarations for iso_c_bmif_2_0 functions.
! Required because NOAA-OWP iso_c_bmif_2_0.f90 was designed for Linux/Mac only.
! Makes symbol visibility explicit on both platforms.

#ifdef _WIN32
!DEC$ ATTRIBUTES DLLEXPORT :: register_bmi
!DEC$ ATTRIBUTES DLLEXPORT :: initialize
!DEC$ ATTRIBUTES DLLEXPORT :: update
!DEC$ ATTRIBUTES DLLEXPORT :: update_until
!DEC$ ATTRIBUTES DLLEXPORT :: finalize
!DEC$ ATTRIBUTES DLLEXPORT :: get_component_name
!DEC$ ATTRIBUTES DLLEXPORT :: get_input_item_count
!DEC$ ATTRIBUTES DLLEXPORT :: get_output_item_count
!DEC$ ATTRIBUTES DLLEXPORT :: get_input_var_names
!DEC$ ATTRIBUTES DLLEXPORT :: get_output_var_names
!DEC$ ATTRIBUTES DLLEXPORT :: get_var_grid
!DEC$ ATTRIBUTES DLLEXPORT :: get_var_type
!DEC$ ATTRIBUTES DLLEXPORT :: get_var_units
!DEC$ ATTRIBUTES DLLEXPORT :: get_var_itemsize
!DEC$ ATTRIBUTES DLLEXPORT :: get_var_nbytes
!DEC$ ATTRIBUTES DLLEXPORT :: get_var_location
!DEC$ ATTRIBUTES DLLEXPORT :: get_current_time
!DEC$ ATTRIBUTES DLLEXPORT :: get_start_time
!DEC$ ATTRIBUTES DLLEXPORT :: get_end_time
!DEC$ ATTRIBUTES DLLEXPORT :: get_time_units
!DEC$ ATTRIBUTES DLLEXPORT :: get_time_step
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_int
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_float
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_double
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_ptr_int
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_ptr_float
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_ptr_double
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_at_indices_int
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_at_indices_float
!DEC$ ATTRIBUTES DLLEXPORT :: get_value_at_indices_double
!DEC$ ATTRIBUTES DLLEXPORT :: set_value_int
!DEC$ ATTRIBUTES DLLEXPORT :: set_value_float
!DEC$ ATTRIBUTES DLLEXPORT :: set_value_double
!DEC$ ATTRIBUTES DLLEXPORT :: set_value_at_indices_int
!DEC$ ATTRIBUTES DLLEXPORT :: set_value_at_indices_float
!DEC$ ATTRIBUTES DLLEXPORT :: set_value_at_indices_double
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_rank
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_size
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_type
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_shape
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_spacing
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_origin
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_x
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_y
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_z
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_node_count
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_edge_count
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_face_count
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_edge_nodes
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_face_edges
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_face_nodes
!DEC$ ATTRIBUTES DLLEXPORT :: get_grid_nodes_per_face
#else
!GCC$ ATTRIBUTES VISIBILITY="default" :: register_bmi
!GCC$ ATTRIBUTES VISIBILITY="default" :: initialize
!GCC$ ATTRIBUTES VISIBILITY="default" :: update
!GCC$ ATTRIBUTES VISIBILITY="default" :: update_until
!GCC$ ATTRIBUTES VISIBILITY="default" :: finalize
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_component_name
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_input_item_count
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_output_item_count
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_input_var_names
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_output_var_names
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_var_grid
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_var_type
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_var_units
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_var_itemsize
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_var_nbytes
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_var_location
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_current_time
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_start_time
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_end_time
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_time_units
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_time_step
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_int
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_float
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_double
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_ptr_int
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_ptr_float
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_ptr_double
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_at_indices_int
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_at_indices_float
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_value_at_indices_double
!GCC$ ATTRIBUTES VISIBILITY="default" :: set_value_int
!GCC$ ATTRIBUTES VISIBILITY="default" :: set_value_float
!GCC$ ATTRIBUTES VISIBILITY="default" :: set_value_double
!GCC$ ATTRIBUTES VISIBILITY="default" :: set_value_at_indices_int
!GCC$ ATTRIBUTES VISIBILITY="default" :: set_value_at_indices_float
!GCC$ ATTRIBUTES VISIBILITY="default" :: set_value_at_indices_double
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_rank
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_size
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_type
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_shape
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_spacing
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_origin
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_x
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_y
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_z
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_node_count
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_edge_count
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_face_count
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_edge_nodes
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_face_edges
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_face_nodes
!GCC$ ATTRIBUTES VISIBILITY="default" :: get_grid_nodes_per_face
#endif

! Dummy module to satisfy Fortran syntax requirements
module iso_c_bmif_2_0_visibility
end module iso_c_bmif_2_0_visibility
