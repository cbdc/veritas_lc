#!/usr/bin/env python
# coding: utf-8
from __future__ import print_function


def print_table(table):
    import json
    print(json.dumps(table.meta, indent=4))
    print(table)


def read_header_keyword(table, keyword, kw_sep='_'):
    '''
    Read value after 'keyword' from table's header

    Input:
     - table : ~astropy.table.Table
     - keyword : str, list of str
         table's header keyword

    Output:
     - {kwjoin:(value,unit)) : mapping of joined 'keyword' (if it's a list)
                                to the corresponding value and unit.
                                If unit is not available, 'None' is returned.
    '''
    def split_name_unit(keyword):
        import re
        regex = '\(.*\)'
        reobj = re.compile(regex)
        unit = reobj.search(keyword)
        if unit:
            unit = re.sub('\(|\)', '', unit.group())
        name = reobj.sub('', keyword)
        return (name, unit)

    kw_sep = kw_sep if isinstance(kw_sep, str) else ''
    value = None
    kwjoin = None
    if isinstance(keyword, str):
        kw_found = False
        for k, v in table.meta.items():
            if k.startswith(keyword):
                value = v
                kwjoin = k
                kw_found = True
        assert kw_found, 'keyword {} not found in header'.format(keyword)
    else:
        assert isinstance(keyword, (list, tuple))
        header_keys = []
        for kw in keyword:
            kw_found = False
            if value is None:
                value = table.meta
            for k, v in value.items():
                if k.startswith(kw):
                    value = v
                    header_keys.append(k)
                    kw_found = True
                    break
            assert kw_found, 'keywords {} not found in header'.format(kw)
        kwjoin = kw_sep.join(header_keys)
    kwjoin, unit = split_name_unit(kwjoin)
    return {kwjoin: (value, unit)}


def keyword2column(table, keyword, unit=None):
    from astropy.table import Column

    kwvalue = read_header_keyword(table, keyword)

    colname, (hfield, unitname) = kwvalue.popitem()
    if unit is not None:
        unitname = unit
    col = Column(data=[hfield]*len(table),
                 name=colname,
                 unit=unitname)
    return col


def header2table(table, keyword, unit=None):
    '''
    Add 'keyword' column (from meta/header) to 'table'

    The column created will have the value from "meta[keyword]"
    (repeated 'len(table)' times) with unit 'unitname' and
    dtype 'datatype'
    '''
    col = keyword2column(table, keyword, unit)
    table.add_column(col)


def mjd_header2table(table):
    '''
    Create columns 'epoch_*' from table's header keywords 'mjd_*'

    mjd_start ---> epoch_ini
    mjd_end   ---> epoch_end
    '''
    header2table(table, ('MJD', 'START'), unit='day')
    header2table(table, ('MJD', 'END'), unit='day')
    table['epoch_ini'] = table['MJD_START']
    table['epoch_end'] = table['MJD_END']
    del table['MJD_START'], table['MJD_END']


def resolve_name(name):
    from astropy.coordinates import get_icrs_coordinates as get_coords
    try:
        icrs = get_coords(name)
        pos = (icrs.ra.value, icrs.dec.value)
    except:
        pos = None
    return pos


def add_radec2header(table):
    assert 'OBJECT' in table.meta
    pos = resolve_name(table.meta['OBJECT'])
    table.meta['RA'] = pos[0]
    table.meta['DEC'] = pos[1]


def flatten_header(table):
    separator = '-'

    def flatten_dict(key, value_dict):
        outish = []
        for k, v in value_dict.items():
            if isinstance(v, dict):
                flat = flatten_dict(k, v)
                for kp, vp in flat:
                    kn = separator.join([str(k), kp])
                    outish.append((kn, vp))
            else:
                outish.append((k, v))
        return [(separator.join([str(key), k]), v) for k, v in outish]
    _meta = table.meta.copy()
    for k, v in _meta.items():
        if isinstance(v, dict):
            flat = flatten_dict(k, v)
            for kn, vn in flat:
                table.meta[kn] = vn
                try:
                    del table.meta[k]
                except:
                    pass
    return table.meta


def shorten_header_keywords(table):
    def shorten_word(word):
        new_word = ''.join(filter(lambda c: c.lower() not in 'aeiou', word))
        if len(new_word) > 8:
            new_word = new_word[:8]
        return new_word
    to_remove = []
    to_add = []
    for k, v in table.meta.items():
        if len(k) > 8:
            assert isinstance(k, str)
            new_k = shorten_word(k)
            to_add.append((new_k, v))
            to_remove.append(k)
            to_add.append(('SUBS_'+new_k, k))
    for new_k, v in to_add:
        table.meta[new_k] = v
    for old_k in to_remove:
        del table.meta[old_k]
    return table.meta


def csv2fits(csv_file, fits_file=None):
    from astropy.table import Table
    from path import Path

    filein = Path(csv_file)
    dirin = filein.abspath().dirname()
    if fits_file is None:
        dirout = dirin.joinpath('../pub')
        fileout = (dirout.joinpath(filein.namebase) + '.fits').normpath()
    else:
        fileout = Path(fits_file).abspath()

    t = Table.read(filein, format='ascii.ecsv')

    # mjd_header2table(t)
    add_radec2header(t)
    flatten_header(t)

    t.write(fileout, format='fits', overwrite=True)
    return t


def main(filein, fileout):
    from astropy.table import Table
    t = Table.read(filein, format='ascii.ecsv')
    print("\n")
    print("==================")
    print("Original/CSV file:")
    print("==================")
    print_table(t)

    t = csv2fits(filein, fileout)
    print("\n")
    print("================")
    print("Converted table:")
    print("================")
    print_table(t)

    t = Table.read(fileout)
    print("\n")
    print("================")
    print("Final/FITS file:")
    print("================")
    print_table(t)


if __name__ == '__main__':
    import sys
    if len(sys.argv) != 3:
        print("Usage: {!s} <input.csv> <output.fits>".format(sys.argv[0]))
        sys.exit(1)
    filein, fileout = sys.argv[1:3]
    main(filein, fileout)
    sys.exit(0)
