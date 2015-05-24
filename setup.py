from setuptools import setup, find_packages


class BuildCommand(distutils.command.build.build):
    pass


class InstallDataCommand(distutils.command.build.build):
    pass


class CleanCommand(distutils.command.build.build):
    pass


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
    data_files = [
        ('', ['COPYING']),
        ('/usr/share/applications', ['share/elementary-notes.desktop']),
        ('/usr/share/pixmaps', glob.glob('share/*.png'))
    ],
    cmdclass={
        'build': BuildCommand,
        'install_data': InstallDataCommand,
        'clean':CleanCommand
    },
    zip_safe=False,
    include_package_data=True
)