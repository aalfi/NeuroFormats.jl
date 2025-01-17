

import Base.getindex, Base.size, Base.length, Base.reinterpret, Base.hton, Base.ntoh, Base.show


""" Models the header section of a file in Curv format. """
struct CurvHeader
    curv_magic_b1::UInt8
    curv_magic_b2::UInt8
    curv_magic_b3::UInt8
    num_vertices::Int32
    num_faces::Int32
    values_per_vertex::Int32
end


""" Models the structure of a file in Curv format. The `header` field contains a [`CurvHeader`](@ref), the `data` field is a Float32 vector of per-vertex values. The values appear in the same order as the the vertices in the corresponding brain mesh (surf) file."""
struct Curv
    header::CurvHeader
    data::Array{Float32, 1}
end

Base.show(io::IO, x::Curv) = @printf("FreeSurfer per-vertex brain surface data for %d vertices.\n", Base.length(x.data))

const CURV_MAGIC_HDR = 16777215::Int64
const CURV_HDR_SIZE = sizeof(CurvHeader)


""" Read header from a Curv file """
function _read_curv_header(io::IO)
    header = CurvHeader(UInt8(hton(read(io,UInt8))), UInt8(hton(read(io,UInt8))), UInt8(hton(read(io,UInt8))), hton(read(io,Int32)), hton(read(io,Int32)), hton(read(io,Int32)))
    if !(header.curv_magic_b1 == 0xff && header.curv_magic_b2 == 0xff && header.curv_magic_b3 == 0xff)
        error("This is not a binary FreeSurfer Curv file: header magic code mismatch.")
    end
    header
end


""" 
    read_curv(file::AbstractString; with_header::Bool=false)

Read per-vertex data for brain meshes from the Curv file `file`. The file must be in FreeSurfer binary `Curv` format, like `lh.thickness`. Returns an Array{Float32,1} with the data unless `with_header` is set, in which case a [`Curv`](@ref) struct is returned instead.

See also: [`write_curv`](@ref)

# Examples
```julia-repl
julia> curv_file = joinpath(tdd(), "subjects_dir/subject1/surf/lh.thickness");
julia> curv = read_curv(curv_file);
julia> sum(curv)/length(curv) # show mean cortical thickness
```
"""
function read_curv(file::AbstractString; with_header::Bool=false)
    file_io = open(file, "r")
    header = _read_curv_header(file_io)
    
    per_vertex_data = _read_vector_endian(file_io, Float32, header.num_vertices, endian="big")
              
    close(file_io)

    if with_header
        curv = Curv(header, per_vertex_data)
        return curv
    else
        return per_vertex_data
    end
end


"""
    write_curv(file::AbstractString, curv_data::Vector{<:Number})

Write a numeric vector to a binary file in FreeSurfer Curv format. The data will be coverted to Float32.

This function is typically used to write surface-based neuroimaging data, like per-vertex cortical thickness
measurements, for a brain mesh.

See also: [`read_curv`](@ref)

# Examples
```julia-repl
julia> write_curv("~/study1/subject1/surf/lh.thickness", convert(Array{Float32}, zeros(100)))
```
"""
function write_curv(file::AbstractString, curv_data::Vector{<:Number})
    curv_data = convert(Vector{Float32}, curv_data)
    header = CurvHeader(0xff, 0xff, 0xff, length(curv_data), 0, 1)
    file_io =  open(file, "w")
    
    # Write header
    write(file_io, ntoh(header.curv_magic_b1))
    write(file_io, ntoh(header.curv_magic_b2))
    write(file_io, ntoh(header.curv_magic_b3))
    write(file_io, ntoh(header.num_vertices))
    write(file_io, ntoh(header.num_faces))
    write(file_io, ntoh(header.values_per_vertex))

    # Write data
    for idx in eachindex(curv_data)
        write(file_io, ntoh(curv_data[idx]))
    end

    close(file_io) 
end

