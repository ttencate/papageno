# Generated by Django 2.0.7 on 2018-07-22 18:49

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('xenocanto', '0003_auto_20180721_1552'),
    ]

    operations = [
        migrations.CreateModel(
            name='Species',
            fields=[
                ('id', models.IntegerField(primary_key=True, serialize=False)),
                ('ioc_name', models.TextField(unique=True)),
            ],
        ),
        migrations.CreateModel(
            name='SpeciesAltName',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('alt_name', models.TextField(unique=True)),
                ('species', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='xenocanto.Species')),
            ],
        ),
        migrations.CreateModel(
            name='SpeciesNameTranslation',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('language', models.TextField()),
                ('translated_name', models.TextField()),
                ('species', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='xenocanto.Species')),
            ],
        ),
        migrations.AlterUniqueTogether(
            name='speciesnametranslation',
            unique_together={('species', 'language')},
        ),
    ]
