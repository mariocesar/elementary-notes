# encoding=utf-8
import glob
from setuptools import setup, find_packages


setup(
    name='elementary-notes',
    description='Note taking for the elementary OS Desktop',
    version='1.0',
    author='Mario César Señoranis Ayala',
    author_email='mariocesar.c50@gmail.com',
    url='https://github.com/mariocesar/elementary-notes',
    package_dir={'': 'src'},
    packages=find_packages('src'),
    scripts=['elementary-note.py'],
    data_files=[
        ('', ['COPYING']),
        ('/usr/share/applications', ['share/elementary-notes.desktop']),
        ('/usr/share/pixmaps', glob.glob('share/*.png'))
    ],
    zip_safe=False,
    include_package_data=True
)
